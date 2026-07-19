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
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
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
import androidx.compose.material3.LinearProgressIndicator
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
import androidx.compose.ui.Modifier
import androidx.compose.ui.Alignment
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.draw.clip
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
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

@Composable
fun FaceRegistrationScreen(
    viewModel: FaceRegistrationViewModel,
    initialEmployeeCode: String = "",
    initialEmployeeId: Int? = null,
    onRegistered: ((Int) -> Unit)? = null,
    onBack: () -> Unit
) {
    val state by viewModel.state.collectAsState()
    var cameraGranted by remember { mutableStateOf(false) }
    val permission = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        cameraGranted = granted
        debug("FACE_REG_PERMISSION_GRANTED", "granted=$granted")
        if (!granted) viewModel.cameraFailure(SecurityException("camera_permission_denied"))
    }

    LaunchedEffect(initialEmployeeCode, initialEmployeeId) {
        debug("FACE_REG_SCREEN_ENTER", "employeeId=${initialEmployeeId ?: -1}")
        if (initialEmployeeId != null && initialEmployeeId > 0) viewModel.findByEmployeeId(initialEmployeeId)
        if (initialEmployeeCode.isNotBlank()) viewModel.find(initialEmployeeCode)
    }
    LaunchedEffect(state.registrationCompleted, state.employee?.id) {
        val employeeId = state.employee?.id
        if (state.registrationCompleted && employeeId != null) {
            viewModel.acknowledgeRegistrationCompleted()
            onRegistered?.invoke(employeeId)
        }
    }

    OSINETScreen {
        val colors = MaterialTheme.colorScheme
        OSINETHeader("Registro facial", "Cinco poses distintas requeridas")
        Text("Advertencia: esta versión no detecta fotografías impresas ni pantallas.", color = colors.error)
        Spacer(Modifier.height(12.dp))
        Text("Empleado: ${state.employee?.employeeCode ?: initialEmployeeCode}", color = colors.onSurface)
        FacePoseProgress(completed = state.samples)
        AnimatedContent(
            targetState = state.currentPose,
            transitionSpec = { fadeIn(tween(350)) togetherWith fadeOut(tween(250)) },
            label = "face_pose_transition"
        ) { pose ->
            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                FacePoseGuide(pose = pose, completed = state.samples)
                Text("Muestra ${state.samples + 1} de 5", style = MaterialTheme.typography.titleMedium, color = colors.primary)
                Text(poseDisplayText(pose), style = MaterialTheme.typography.titleMedium, color = colors.onSurface)
            }
        }
        AnimatedVisibility(
            visible = state.samples > 0,
            enter = fadeIn(tween(300)) + scaleIn(tween(300)),
            exit = fadeOut(tween(180)) + scaleOut(tween(180))
        ) { Text("✓ Pose completada", color = colors.primary, style = MaterialTheme.typography.labelLarge) }
        Text(state.message, color = if (state.cameraError) colors.error else colors.onSurfaceVariant)
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = {
                    viewModel.beginCapture()
                    permission.launch(Manifest.permission.CAMERA)
                },
                enabled = state.employee != null && !state.capturing && !state.saving
            ) { Text(if (state.cameraError) "Reintentar" else if (state.registered) "Actualizar rostro" else "Registrar rostro") }
            OutlinedButton(onClick = { viewModel.remove() }, enabled = state.registered && !state.capturing && !state.saving) { Text("Eliminar rostro") }
        }
        if (state.capturing && cameraGranted) {
            FaceRegistrationCamera(
                onPoseSample = viewModel::observeFace,
                onGuidance = viewModel::guidance,
                onError = viewModel::cameraFailure,
                pose = state.currentPose,
                completed = state.samples
            )
        } else if (state.capturing) {
            Text("Se necesita permiso de cámara para registrar el rostro.", color = colors.error)
        }
        if (state.cameraError) {
            Spacer(Modifier.height(12.dp))
            Text("No se pudo iniciar el registro facial.", color = colors.error)
            OutlinedButton(onClick = onBack) { Text("Volver al PIN") }
        }
        AnimatedVisibility(
            visible = state.registered && state.samples == FaceRegistrationPose.entries.size,
            enter = fadeIn(tween(350)) + scaleIn(tween(400)),
            exit = fadeOut(tween(180)) + scaleOut(tween(180))
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                Text("✓", color = colors.primary, style = MaterialTheme.typography.displayLarge)
                Text("Registro facial completado", color = colors.primary, style = MaterialTheme.typography.titleLarge)
            }
        }
        Spacer(Modifier.height(12.dp))
        OutlinedButton(onClick = onBack) { Text("Volver") }
    }
}

@Composable
private fun FacePoseProgress(completed: Int) {
    val colors = MaterialTheme.colorScheme
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        LinearProgressIndicator(
            progress = { completed.toFloat() / FaceRegistrationPose.entries.size },
            modifier = Modifier.fillMaxWidth(),
            color = colors.primary,
            trackColor = colors.surfaceVariant
        )
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            FaceRegistrationPose.entries.forEachIndexed { index, _ ->
                Canvas(Modifier.size(16.dp)) {
                    drawCircle(
                        color = if (index < completed) colors.primary else colors.outlineVariant,
                        radius = size.minDimension / 2f,
                        style = if (index < completed) Stroke(width = 5f) else Stroke(width = 3f)
                    )
                    if (index < completed) drawCircle(color = colors.primary, radius = size.minDimension / 5f)
                }
            }
        }
    }
}

@Composable
private fun FacePoseGuide(pose: FaceRegistrationPose, completed: Int) {
    val colors = MaterialTheme.colorScheme
    val pulse = rememberInfiniteTransition(label = "face_pose_pulse")
        .animateFloat(
            initialValue = 0.75f,
            targetValue = 1.05f,
            animationSpec = infiniteRepeatable(tween(850, easing = FastOutSlowInEasing), RepeatMode.Reverse),
            label = "face_pose_scale"
        ).value
    val direction = when (pose) {
        FaceRegistrationPose.LEFT -> -1f
        FaceRegistrationPose.RIGHT -> 1f
        else -> 0f
    }
    val vertical = when (pose) {
        FaceRegistrationPose.UP -> -1f
        FaceRegistrationPose.DOWN -> 1f
        else -> 0f
    }
    val offsetX by animateFloatAsState(direction * 10f * pulse, tween(360), label = "face_pose_x")
    val offsetY by animateFloatAsState(vertical * 10f * pulse, tween(360), label = "face_pose_y")
    Canvas(Modifier.fillMaxWidth().height(150.dp)) {
        val center = Offset(size.width / 2f + offsetX, size.height / 2f + offsetY)
        val radius = size.minDimension.coerceAtMost(108.dp.toPx()) * 0.30f
        drawCircle(colors.surfaceVariant, radius, center)
        drawCircle(colors.primary.copy(alpha = 0.35f + (pulse - 0.75f)), radius + 12.dp.toPx(), center, style = Stroke(4.dp.toPx()))
        drawCircle(colors.onSurface, radius * .10f, Offset(center.x - radius * .35f, center.y - radius * .1f))
        drawCircle(colors.onSurface, radius * .10f, Offset(center.x + radius * .35f, center.y - radius * .1f))
        drawLine(colors.onSurface, Offset(center.x - radius * .30f, center.y + radius * .35f), Offset(center.x + radius * .30f, center.y + radius * .35f), 4.dp.toPx())
        if (direction != 0f || vertical != 0f) {
            val start = Offset(center.x - direction * radius * 1.55f, center.y - vertical * radius * 1.55f)
            val end = Offset(center.x + direction * radius * 1.55f, center.y + vertical * radius * 1.55f)
            drawLine(colors.primary, start, end, 5.dp.toPx())
            drawCircle(colors.primary, 8.dp.toPx(), end)
        }
        if (completed > 0) drawCircle(colors.primary, 10.dp.toPx(), Offset(size.width - 18.dp.toPx(), 18.dp.toPx()))
    }
}

@Composable
private fun FaceCameraOverlay(pose: FaceRegistrationPose, completed: Int, modifier: Modifier = Modifier) {
    val colors = MaterialTheme.colorScheme
    val pulse = rememberInfiniteTransition(label = "camera_overlay_pulse")
        .animateFloat(
            initialValue = 0.98f,
            targetValue = 1.02f,
            animationSpec = infiniteRepeatable(tween(1_000), RepeatMode.Reverse),
            label = "camera_overlay_scale"
        ).value
    Box(modifier) {
        Canvas(Modifier.fillMaxSize()) {
            val center = Offset(size.width / 2f, size.height / 2f)
            val radiusX = size.width * .30f * pulse
            val radiusY = size.height * .36f * pulse
            val border = if (completed > 0) colors.primary else colors.secondary
            drawOval(
                color = border.copy(alpha = .92f),
                topLeft = Offset(center.x - radiusX, center.y - radiusY),
                size = androidx.compose.ui.geometry.Size(radiusX * 2, radiusY * 2),
                style = Stroke(width = 4.dp.toPx())
            )
        }
        Text(
            text = poseDisplayText(pose),
            color = Color(0xFFEAEAEA),
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .clip(RoundedCornerShape(16.dp))
                .background(colors.scrim.copy(alpha = .68f))
                .padding(16.dp)
        )
    }
}

private fun poseDisplayText(pose: FaceRegistrationPose): String = when (pose) {
    FaceRegistrationPose.FRONT -> "Mire al frente"
    FaceRegistrationPose.LEFT -> "Gire ligeramente hacia la izquierda"
    FaceRegistrationPose.RIGHT -> "Gire ligeramente hacia la derecha"
    FaceRegistrationPose.UP -> "Levante ligeramente el rostro"
    FaceRegistrationPose.DOWN -> "Baje ligeramente el rostro"
}

@Composable
private fun FaceRegistrationCamera(
    onPoseSample: (y: Float, x: Float, z: Float, embedding: FloatArray) -> Boolean,
    onGuidance: (String) -> Unit,
    onError: (Throwable) -> Unit,
    pose: FaceRegistrationPose,
    completed: Int
) {
    val lifecycle = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val processing = remember { AtomicBoolean(false) }
    val firstFrameLogged = remember { AtomicBoolean(false) }
    val nextCaptureAt = remember { longArrayOf(0L) }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    var engine by remember { mutableStateOf<FaceEmbeddingEngine?>(null) }
    var detector by remember { mutableStateOf<FaceDetector?>(null) }
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
            factory = { context ->
            PreviewView(context).also { previewView ->
                val providerFuture = ProcessCameraProvider.getInstance(context)
                providerFuture.addListener({
                    runCatching {
                        val currentProvider = providerFuture.get()
                        provider = currentProvider
                        debug("FACE_REG_CAMERA_PROVIDER_READY", "ready=true")
                        check(currentProvider.hasCamera(CameraSelector.DEFAULT_FRONT_CAMERA)) { "front_camera_unavailable" }
                        val currentEngine = FaceEmbeddingEngine(context)
                        engine = currentEngine
                        debug("FACE_REG_MODEL_READY", "ready=true")
                        val currentDetector = FaceDetection.getClient(
                            FaceDetectorOptions.Builder().setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE).build()
                        )
                        detector = currentDetector
                        debug("FACE_REG_DETECTOR_READY", "ready=true")
                        val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
                        analysis.setAnalyzer(executor) { proxy ->
                            val media = proxy.image
                            if (media == null || !processing.compareAndSet(false, true)) {
                                proxy.close()
                                return@setAnalyzer
                            }
                            // Copy before ML Kit consumes the ImageProxy. Its plane buffers are invalid in callbacks.
                            val rotationDegrees = proxy.imageInfo.rotationDegrees
                            val sourceBitmap = proxy.yPlaneBitmapOrNull()
                            if (sourceBitmap == null) {
                                processing.set(false)
                                proxy.close()
                                onError(IllegalStateException("y_plane_unavailable"))
                                return@setAnalyzer
                            }
                            val frameBitmap = sourceBitmap.rotated(rotationDegrees)
                            if (firstFrameLogged.compareAndSet(false, true)) debug("FACE_REG_FIRST_FRAME", "received=true")
                            currentDetector.process(InputImage.fromMediaImage(media, rotationDegrees))
                                .addOnSuccessListener(executor) { faces ->
                                    debug(
                                        "FACE_REG_FRAME",
                                        "faces=${faces.size} rotation=$rotationDegrees pose=$pose samples=$completed"
                                    )
                                    when {
                                        faces.isEmpty() -> {
                                            debug("FACE_REG_FRAME", "validation=NO_FACE pose=$pose")
                                            onGuidance("Mire directamente a la cámara")
                                        }
                                        faces.size > 1 -> {
                                            debug("FACE_REG_FRAME", "validation=MULTIPLE_FACES pose=$pose")
                                            onGuidance("Centre un \u00FAnico rostro")
                                        }
                                        else -> runCatching {
                                            val face = faces.single()
                                            val bounds = face.boundingBox
                                            val quality = frameBitmap.qualityIssue()
                                            debug(
                                                "FACE_REG_FRAME",
                                                "x=${face.headEulerAngleX} y=${face.headEulerAngleY} " +
                                                    "z=${face.headEulerAngleZ} pose=$pose samples=$completed"
                                            )
                                            when {
                                                bounds.width() < frameBitmap.width / 4 || bounds.height() < frameBitmap.height / 4 -> {
                                                    debug("FACE_REG_FRAME", "validation=FACE_TOO_SMALL pose=$pose")
                                                    onGuidance("Ac\u00E9rquese")
                                                }
                                                bounds.width() > frameBitmap.width * 9 / 10 || bounds.height() > frameBitmap.height * 9 / 10 -> {
                                                    debug("FACE_REG_FRAME", "validation=FACE_TOO_LARGE pose=$pose")
                                                    onGuidance("Al\u00E9jese")
                                                }
                                                !bounds.isInside(frameBitmap.width, frameBitmap.height) -> {
                                                    debug("FACE_REG_FRAME", "validation=FACE_NOT_CENTERED pose=$pose")
                                                    onGuidance("Centre su rostro")
                                                }
                                                quality != null -> {
                                                    debug("FACE_REG_FRAME", "validation=IMAGE_QUALITY pose=$pose reason=$quality")
                                                    onGuidance(quality)
                                                }
                                                System.currentTimeMillis() < nextCaptureAt[0] -> {
                                                    debug("FACE_REG_FRAME", "validation=SAMPLE_COOLDOWN pose=$pose")
                                                    Unit
                                                }
                                                else -> {
                                                    val embedding = currentEngine.embedding(frameBitmap, Rect(bounds))
                                                    val accepted = onPoseSample(face.headEulerAngleY, face.headEulerAngleX, face.headEulerAngleZ, embedding)
                                                    debug(
                                                        "FACE_REGISTRATION_POSE",
                                                        "x=${face.headEulerAngleX} y=${face.headEulerAngleY} " +
                                                            "z=${face.headEulerAngleZ} pose=$pose validation=" +
                                                            if (accepted) "READY" else "POSE_NOT_REACHED"
                                                    )
                                                    if (accepted) nextCaptureAt[0] = System.currentTimeMillis() + CAPTURE_COOLDOWN_MS
                                                }
                                            }
                                        }.onFailure(onError)
                                    }
                                }
                                .addOnFailureListener(executor, onError)
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
                        debug("FACE_REG_CAMERA_BOUND", "front=true")
                    }.onFailure { error ->
                        provider?.unbindAll()
                        onError(error)
                    }
                }, ContextCompat.getMainExecutor(context))
            }
            },
            modifier = Modifier.fillMaxSize()
        )
        FaceCameraOverlay(pose = pose, completed = completed, modifier = Modifier.fillMaxSize())
    }
}

private fun Rect.isInside(width: Int, height: Int): Boolean = left >= 0 && top >= 0 && right <= width && bottom <= height

private fun Bitmap.rotated(rotationDegrees: Int): Bitmap {
    if (rotationDegrees % 360 == 0) return this
    val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
    return Bitmap.createBitmap(this, 0, 0, width, height, matrix, true)
}

private fun Bitmap.qualityIssue(): String? {
    var sum = 0.0; var squareSum = 0.0; var count = 0
    for (y in 0 until height step 16) for (x in 0 until width step 16) {
        val luminance = getPixel(x, y) and 0xff
        sum += luminance; squareSum += luminance * luminance; count++
    }
    val mean = sum / count
    val variance = squareSum / count - mean * mean
    return when {
        mean < 45 -> "Mejore la iluminación"
        mean > 225 -> "Reduzca la iluminación"
        variance < 80 -> "Mantenga el rostro quieto"
        else -> null
    }
}

private fun androidx.camera.core.ImageProxy.yPlaneBitmapOrNull(): Bitmap? = runCatching {
    val plane = planes.firstOrNull() ?: return null
    val buffer = plane.buffer ?: return null
    val duplicate = buffer.duplicate()
    val bytes = ByteArray(duplicate.remaining()).also { duplicate.get(it) }
    val pixels = IntArray(width * height)
    for (y in 0 until height) for (x in 0 until width) {
        val index = y * plane.rowStride + x * plane.pixelStride
        require(index in bytes.indices)
        val luminance = bytes[index].toInt() and 0xff
        pixels[y * width + x] = android.graphics.Color.rgb(luminance, luminance, luminance)
    }
    Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
}.getOrNull()

private fun debug(tag: String, message: String) {
    if (BuildConfig.DEBUG) Log.d(tag, message)
}

private const val CAPTURE_COOLDOWN_MS = 500L
