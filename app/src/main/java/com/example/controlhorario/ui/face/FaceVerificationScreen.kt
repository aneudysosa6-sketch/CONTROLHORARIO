package com.example.controlhorario.ui.face

import android.Manifest
import android.graphics.Bitmap
import android.graphics.Matrix
import android.graphics.Rect
import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.face.FaceEmbeddingEngine
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import kotlinx.coroutines.delay
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

@Composable
fun FaceVerificationScreen(
    viewModel: FaceVerificationViewModel,
    onRecognized: () -> Unit,
    onCancel: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    var cameraGranted by remember { mutableStateOf(false) }
    var navigationConsumed by remember { mutableStateOf(false) }
    var guidance by remember { mutableStateOf("Centre su rostro") }
    var visualAttempt by remember { mutableStateOf(1) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        cameraGranted = it
    }

    LaunchedEffect(Unit) {
        viewModel.load()
        permission.launch(Manifest.permission.CAMERA)
    }
    LaunchedEffect(state) {
        if (state == FaceVerificationState.NotRecognized) {
            visualAttempt = (visualAttempt + 1).coerceAtMost(MAX_VISUAL_ATTEMPTS)
        }
        when (state) {
            FaceVerificationState.Recognized -> if (!navigationConsumed) {
                navigationConsumed = true
                onRecognized()
            }
            FaceVerificationState.AttemptsExhausted -> {
                delay(1_200)
                if (!navigationConsumed) {
                    navigationConsumed = true
                    onCancel()
                }
            }
            else -> Unit
        }
    }

    OSINETScreen {
        OSINETHeader("Validación facial", "Mire la cámara frontal para continuar")
        when (state) {
            FaceVerificationState.Loading -> Progress("Preparando cámara")
            FaceVerificationState.FaceNotRegistered -> Message(
                "Este empleado no tiene un rostro registrado. Contacte al administrador.",
                onCancel
            )
            FaceVerificationState.InvalidTemplate -> Message(
                "El registro facial debe actualizarse. Contacte al administrador.",
                onCancel
            )
            is FaceVerificationState.Error -> Message((state as FaceVerificationState.Error).message, onCancel)
            FaceVerificationState.Recognized -> VerificationResult(
                success = true,
                message = "Identidad confirmada"
            )
            FaceVerificationState.AttemptsExhausted -> VerificationResult(
                success = false,
                message = "No se pudo verificar el rostro"
            )
            else -> {
                val displayMessage = when (state) {
                    FaceVerificationState.Processing -> "Verificando rostro del empleado"
                    FaceVerificationState.NotRecognized -> "Rostro no reconocido. Intente nuevamente."
                    else -> guidance
                }
                VerificationAttemptIndicator(attempt = visualAttempt)
                Spacer(Modifier.height(12.dp))
                if (cameraGranted) {
                    FaceEmbeddingCamera(
                        onEmbedding = { embedding, _ -> viewModel.score(embedding) },
                        onGuidance = { guidance = it },
                        visualState = state,
                        message = displayMessage,
                        attempt = visualAttempt
                    )
                } else {
                    VerificationInstructionCard("Se necesita permiso de cámara para validar el rostro.")
                }
                Spacer(Modifier.height(16.dp))
                OutlinedButton(onClick = onCancel, modifier = Modifier.fillMaxWidth()) { Text("Cancelar") }
            }
        }
    }
}

@Composable
private fun Progress(message: String) {
    val colors = MaterialTheme.colorScheme
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth().padding(24.dp)
    ) {
        CircularProgressIndicator(color = colors.primary)
        VerificationInstructionCard(message)
    }
}

@Composable
private fun Message(message: String, onCancel: () -> Unit) {
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth().padding(24.dp)
    ) {
        VerificationInstructionCard(message)
        Button(onClick = onCancel) { Text("Volver al código") }
    }
}

@Composable
private fun VerificationInstructionCard(message: String) {
    Text(
        text = message,
        color = Color(0xFFEAEAEA),
        style = MaterialTheme.typography.titleMedium,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.scrim.copy(alpha = .70f))
            .padding(16.dp),
        textAlign = androidx.compose.ui.text.style.TextAlign.Center
    )
}

@Composable
private fun VerificationAttemptIndicator(attempt: Int) {
    val colors = MaterialTheme.colorScheme
    val selectedAttempt = attempt.coerceIn(1, MAX_VISUAL_ATTEMPTS)
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.fillMaxWidth()
    ) {
        Text(
            text = "Intento $selectedAttempt de $MAX_VISUAL_ATTEMPTS",
            style = MaterialTheme.typography.labelLarge,
            color = colors.onSurface
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            repeat(MAX_VISUAL_ATTEMPTS) { index ->
                Canvas(Modifier.size(14.dp)) {
                    val active = index < selectedAttempt
                    drawCircle(
                        color = if (active) colors.primary else colors.outlineVariant,
                        radius = size.minDimension / 2f,
                        style = if (active) Stroke(width = 5f) else Stroke(width = 2.5f)
                    )
                    if (active) drawCircle(colors.primary, size.minDimension / 5f)
                }
            }
        }
    }
}

@Composable
private fun VerificationResult(success: Boolean, message: String) {
    val colors = MaterialTheme.colorScheme
    AnimatedVisibility(
        visible = true,
        enter = fadeIn(tween(260)) + scaleIn(tween(340)),
        exit = fadeOut(tween(160)) + scaleOut(tween(160))
    ) {
        Column(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.fillMaxWidth().padding(24.dp)
        ) {
            Text(
                text = if (success) "✓" else "!",
                color = if (success) colors.primary else colors.error,
                style = MaterialTheme.typography.displayLarge
            )
            Text(
                text = message,
                color = if (success) colors.primary else colors.error,
                style = MaterialTheme.typography.titleLarge
            )
        }
    }
}

@Composable
@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
internal fun FaceEmbeddingCamera(
    onEmbedding: (FloatArray, Long) -> Unit,
    onGuidance: (String) -> Unit,
    visualState: FaceVerificationState,
    message: String,
    attempt: Int
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val processing = remember { AtomicBoolean(false) }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    var engine by remember { mutableStateOf<FaceEmbeddingEngine?>(null) }
    var detector by remember { mutableStateOf<com.google.mlkit.vision.face.FaceDetector?>(null) }
    DisposableEffect(Unit) {
        onDispose {
            provider?.unbindAll()
            detector?.close()
            engine?.close()
            executor.shutdown()
        }
    }

    Box(Modifier.fillMaxWidth().height(360.dp)) {
        AndroidView(
            factory = { viewContext ->
            PreviewView(viewContext).also { previewView ->
                val providerFuture = ProcessCameraProvider.getInstance(viewContext)
                providerFuture.addListener({
                    val currentProvider = providerFuture.get()
                    provider = currentProvider
                    val currentEngine = FaceEmbeddingEngine(viewContext)
                    engine = currentEngine
                    val currentDetector = FaceDetection.getClient(
                        FaceDetectorOptions.Builder()
                            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                            .build()
                    )
                    detector = currentDetector
                    val analysis = ImageAnalysis.Builder()
                        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                        .build()
                    analysis.setAnalyzer(executor) { proxy ->
                        val image = proxy.image
                        if (image == null || !processing.compareAndSet(false, true)) {
                            proxy.close()
                            return@setAnalyzer
                        }
                        val rotationDegrees = proxy.imageInfo.rotationDegrees
                        val sourceBitmap = proxy.yPlaneBitmap()
                        val frameBitmap = sourceBitmap.rotated(rotationDegrees)
                        currentDetector.process(InputImage.fromMediaImage(image, rotationDegrees))
                            .addOnSuccessListener(executor) { faces ->
                                when {
                                    faces.isEmpty() -> {
                                        verifyLog(
                                            "FACE_VERIFY_FRAME",
                                            "faces=0 rotation=$rotationDegrees attempt=$attempt state=$visualState reason=NO_FACE"
                                        )
                                        onGuidance("Mire directamente a la cámara")
                                    }
                                    faces.size > 1 -> {
                                        verifyLog(
                                            "FACE_VERIFY_FRAME",
                                            "faces=${faces.size} rotation=$rotationDegrees attempt=$attempt " +
                                                "state=$visualState reason=MULTIPLE_FACES"
                                        )
                                        onGuidance("Centre un único rostro")
                                    }
                                    else -> {
                                        val bounds = faces.single().boundingBox
                                        val face = faces.single()
                                        val quality = frameBitmap.faceQuality(bounds)
                                        verifyLog(
                                            "FACE_VERIFY_FRAME",
                                            "faces=1 eulerX=${face.headEulerAngleX} eulerY=${face.headEulerAngleY} " +
                                                "eulerZ=${face.headEulerAngleZ} bounds=${bounds.left},${bounds.top}," +
                                                "${bounds.right},${bounds.bottom} faceSize=${bounds.width()}x${bounds.height()} " +
                                                "frame=${frameBitmap.width}x${frameBitmap.height} rotation=$rotationDegrees " +
                                                "attempt=$attempt state=$visualState"
                                        )
                                        when {
                                            bounds.width() < frameBitmap.width / 4 || bounds.height() < frameBitmap.height / 4 -> {
                                                verifyLog("FACE_VERIFY_QUALITY", "reason=FACE_TOO_SMALL attempt=$attempt")
                                                onGuidance("Acérquese a la cámara")
                                            }
                                            bounds.width() > frameBitmap.width * 9 / 10 || bounds.height() > frameBitmap.height * 9 / 10 -> {
                                                verifyLog("FACE_VERIFY_QUALITY", "reason=FACE_TOO_LARGE attempt=$attempt")
                                                onGuidance("Aléjese ligeramente de la cámara")
                                            }
                                            !bounds.isInside(frameBitmap.width, frameBitmap.height) -> {
                                                verifyLog("FACE_VERIFY_QUALITY", "reason=FACE_NOT_CENTERED attempt=$attempt")
                                                onGuidance("Centre el rostro")
                                            }
                                            quality.meanLuminance < MIN_FACE_LUMINANCE -> {
                                                verifyLight(quality, bounds, rotationDegrees, attempt, "TOO_DARK")
                                                onGuidance("Aumente ligeramente la iluminación")
                                            }
                                            quality.meanLuminance > MAX_FACE_LUMINANCE -> {
                                                verifyLight(quality, bounds, rotationDegrees, attempt, "OVEREXPOSED")
                                                onGuidance("Evite la luz directa")
                                            }
                                            else -> {
                                                verifyLight(quality, bounds, rotationDegrees, attempt, "PASS")
                                                val embeddingStartedAt = System.nanoTime()
                                                runCatching { currentEngine.embedding(frameBitmap, bounds) }
                                                    .onSuccess {
                                                        val embeddingMs = ((System.nanoTime() - embeddingStartedAt) / 1_000_000L).coerceAtLeast(0L)
                                                        verifyLog(
                                                            "FACE_VERIFY_QUALITY",
                                                            "contrast=${quality.contrast} sharpness=${quality.sharpness} " +
                                                                "attempt=$attempt result=EMBEDDING_READY"
                                                        )
                                                        onEmbedding(it, embeddingMs)
                                                    }
                                                    .onFailure { error ->
                                                        verifyLog(
                                                            "FACE_VERIFY_QUALITY",
                                                            "attempt=$attempt reason=EMBEDDING_FAILED type=" +
                                                                "${error.javaClass.simpleName}"
                                                        )
                                                        onGuidance("Mantenga el rostro quieto")
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                            .addOnCompleteListener {
                                processing.set(false)
                                proxy.close()
                            }
                    }
                    currentProvider.unbindAll()
                    currentProvider.bindToLifecycle(
                        lifecycle,
                        CameraSelector.DEFAULT_FRONT_CAMERA,
                        Preview.Builder().build().also { it.surfaceProvider = previewView.surfaceProvider },
                        analysis
                    )
                }, ContextCompat.getMainExecutor(viewContext))
            }
            },
            modifier = Modifier.fillMaxSize()
        )
        FaceVerificationOverlay(
            state = visualState,
            message = message,
            attempt = attempt,
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
private fun FaceVerificationOverlay(
    state: FaceVerificationState,
    message: String,
    attempt: Int,
    modifier: Modifier = Modifier
) {
    val colors = MaterialTheme.colorScheme
    val pulse = rememberInfiniteTransition(label = "verification_overlay_pulse")
        .animateFloat(
            initialValue = .98f,
            targetValue = 1.02f,
            animationSpec = infiniteRepeatable(
                animation = tween(1_000),
                repeatMode = RepeatMode.Reverse
            ),
            label = "verification_overlay_scale"
        ).value
    val border = when (state) {
        FaceVerificationState.Recognized -> colors.primary
        FaceVerificationState.NotRecognized,
        FaceVerificationState.AttemptsExhausted,
        is FaceVerificationState.Error -> colors.error
        FaceVerificationState.Processing -> colors.secondary
        else -> colors.outline
    }
    val isSuccess = state == FaceVerificationState.Recognized
    val isError = state == FaceVerificationState.NotRecognized ||
        state == FaceVerificationState.AttemptsExhausted ||
        state is FaceVerificationState.Error

    Box(modifier) {
        Canvas(Modifier.fillMaxSize()) {
            val center = Offset(size.width / 2f, size.height / 2f)
            val radiusX = size.width * .30f * pulse
            val radiusY = size.height * .36f * pulse
            drawOval(
                color = border.copy(alpha = .94f),
                topLeft = Offset(center.x - radiusX, center.y - radiusY),
                size = androidx.compose.ui.geometry.Size(radiusX * 2, radiusY * 2),
                style = Stroke(width = 4.dp.toPx())
            )
        }
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .padding(16.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(colors.scrim.copy(alpha = .72f))
                .padding(16.dp)
        ) {
            AnimatedContent(
                targetState = message,
                transitionSpec = {
                    fadeIn(tween(220)) togetherWith fadeOut(tween(160))
                },
                label = "verification_message_transition"
            ) { currentMessage ->
                Text(
                    text = currentMessage,
                    color = Color(0xFFEAEAEA),
                    style = MaterialTheme.typography.titleMedium,
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(
                text = "Intento ${attempt.coerceIn(1, MAX_VISUAL_ATTEMPTS)} de $MAX_VISUAL_ATTEMPTS",
                color = Color.White,
                style = MaterialTheme.typography.labelLarge
            )
            AnimatedVisibility(
                visible = isSuccess || isError,
                enter = fadeIn(tween(220)) + scaleIn(tween(280)),
                exit = fadeOut(tween(150)) + scaleOut(tween(150))
            ) {
                Text(
                    text = if (isSuccess) "✓ Rostro reconocido" else "! No se pudo verificar el rostro",
                    color = if (isSuccess) colors.primary else colors.error,
                    style = MaterialTheme.typography.titleMedium
                )
            }
        }
    }
}

private data class FaceFrameQuality(
    val meanLuminance: Float,
    val contrast: Float,
    val sharpness: Float
)

private fun Bitmap.faceQuality(bounds: Rect): FaceFrameQuality {
    val left = bounds.left.coerceIn(0, width - 1)
    val top = bounds.top.coerceIn(0, height - 1)
    val right = bounds.right.coerceIn(left + 1, width)
    val bottom = bounds.bottom.coerceIn(top + 1, height)
    var sum = 0.0
    var squareSum = 0.0
    var sharpnessSum = 0.0
    var samples = 0
    for (y in top until bottom step FACE_QUALITY_STEP) {
        for (x in left until right step FACE_QUALITY_STEP) {
            val luminance = getPixel(x, y) and 0xff
            sum += luminance
            squareSum += luminance * luminance
            if (x + 1 < right) {
                val adjacent = getPixel(x + 1, y) and 0xff
                sharpnessSum += kotlin.math.abs(luminance - adjacent)
            }
            samples++
        }
    }
    require(samples > 0) { "empty_face_region" }
    val mean = (sum / samples).toFloat()
    val contrast = kotlin.math.sqrt((squareSum / samples) - (mean * mean)).toFloat()
    return FaceFrameQuality(
        meanLuminance = mean,
        contrast = contrast,
        sharpness = (sharpnessSum / samples).toFloat()
    )
}

private fun Bitmap.rotated(rotationDegrees: Int): Bitmap {
    if (rotationDegrees % 360 == 0) return this
    return Bitmap.createBitmap(
        this,
        0,
        0,
        width,
        height,
        Matrix().apply { postRotate(rotationDegrees.toFloat()) },
        true
    )
}

private fun Rect.isInside(width: Int, height: Int): Boolean =
    left >= 0 && top >= 0 && right <= width && bottom <= height

private fun verifyLight(
    quality: FaceFrameQuality,
    bounds: Rect,
    rotationDegrees: Int,
    attempt: Int,
    result: String
) {
    verifyLog(
        "FACE_VERIFY_LIGHT",
        "luminance=${quality.meanLuminance} scale=0-255 min=$MIN_FACE_LUMINANCE " +
            "max=$MAX_FACE_LUMINANCE contrast=${quality.contrast} sharpness=${quality.sharpness} " +
            "bounds=${bounds.left},${bounds.top},${bounds.right},${bounds.bottom} " +
            "rotation=$rotationDegrees attempt=$attempt result=$result"
    )
}

private fun verifyLog(tag: String, message: String) {
    if (BuildConfig.DEBUG) Log.d(tag, message)
}

private fun androidx.camera.core.ImageProxy.yPlaneBitmap(): Bitmap {
    val plane = planes[0]
    val buffer = plane.buffer.duplicate()
    val bytes = ByteArray(buffer.remaining()).also { buffer.get(it) }
    val pixels = IntArray(width * height)
    for (y in 0 until height) for (x in 0 until width) {
        val lum = bytes[y * plane.rowStride + x * plane.pixelStride].toInt() and 0xff
        pixels[y * width + x] = android.graphics.Color.rgb(lum, lum, lum)
    }
    return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
}

private const val MAX_VISUAL_ATTEMPTS = 3
private const val FACE_QUALITY_STEP = 4
private const val MIN_FACE_LUMINANCE = 35f
private const val MAX_FACE_LUMINANCE = 235f
