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
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.semantics
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
import com.example.controlhorario.face.CloseOnce
import com.example.controlhorario.face.FaceFrameGate
import com.example.controlhorario.face.FaceFrameSafety
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
    onBack: () -> Unit,
    backLabel: String = "Volver",
    initialRegistrationOnly: Boolean = false,
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
            crashLog("stage=navigation employeeId=$employeeId")
            viewModel.acknowledgeRegistrationCompleted()
            onRegistered?.invoke(employeeId)
        }
    }

    OSINETScreen {
        val colors = MaterialTheme.colorScheme
        OSINETHeader(
            if (initialRegistrationOnly) "Registro inicial de rostro" else "Registro facial",
            "Cinco poses distintas requeridas",
        )
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
        Text(
            state.message,
            color = if (state.cameraError) colors.error else colors.onSurfaceVariant,
            modifier = Modifier.semantics { liveRegion = LiveRegionMode.Polite },
        )
        val initialRegistrationLocked = initialRegistrationOnly && state.registered
        if (initialRegistrationLocked) {
            Text(
                "Este empleado ya tiene un rostro registrado.\n" +
                    "Solicite a un administrador si necesita reemplazarlo.",
                color = colors.error,
                style = MaterialTheme.typography.bodyMedium,
            )
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(
                onClick = {
                    viewModel.beginCapture()
                    permission.launch(Manifest.permission.CAMERA)
                },
                enabled = state.employee != null && !state.capturing && !state.saving && !initialRegistrationLocked
            ) {
                Text(
                    if (initialRegistrationLocked) "Rostro ya registrado"
                    else if (state.cameraError) "Reintentar"
                    else if (state.registered) "Actualizar rostro"
                    else "Registrar rostro"
                )
            }
            if (!initialRegistrationOnly) {
                OutlinedButton(onClick = { viewModel.remove() }, enabled = state.registered && !state.capturing && !state.saving) { Text("Eliminar rostro") }
            }
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
        if (state.cameraError && !initialRegistrationOnly) {
            Spacer(Modifier.height(12.dp))
            Text("No se pudo iniciar el registro facial.", color = colors.error)
            OutlinedButton(onClick = onBack) { Text("Volver al modo empleado") }
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
        OutlinedButton(onClick = onBack) { Text(backLabel) }
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
@androidx.annotation.OptIn(androidx.camera.core.ExperimentalGetImage::class)
private fun FaceRegistrationCamera(
    onPoseSample: (y: Float, x: Float, z: Float, embedding: FloatArray) -> Boolean,
    onGuidance: (String) -> Unit,
    onError: (Throwable) -> Unit,
    pose: FaceRegistrationPose,
    completed: Int
) {
    val context = LocalContext.current
    val lifecycle = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    val processing = remember { FaceFrameGate() }
    val firstFrameLogged = remember { AtomicBoolean(false) }
    val nextCaptureAt = remember { longArrayOf(0L) }
    var provider by remember { mutableStateOf<ProcessCameraProvider?>(null) }
    var engine by remember { mutableStateOf<FaceEmbeddingEngine?>(null) }
    var detector by remember { mutableStateOf<FaceDetector?>(null) }
    val active = remember { AtomicBoolean(true) }
    val mainExecutor = remember(context) { ContextCompat.getMainExecutor(context) }
    DisposableEffect(Unit) {
        onDispose {
            active.set(false)
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
                            crashLog("stage=analyzer_started")
                            val closeOnce = CloseOnce(proxy::close)
                            val media = proxy.image
                            if (media == null || !processing.tryAcquire()) {
                                closeOnce.close()
                                return@setAnalyzer
                            }
                            val rotationDegrees: Int
                            val luma: ByteArray
                            try {
                                rotationDegrees = proxy.imageInfo.rotationDegrees
                                val plane = proxy.planes.firstOrNull() ?: error("y_plane_missing")
                                luma = FaceFrameSafety.copyLuma(plane.buffer, proxy.width, proxy.height, plane.rowStride, plane.pixelStride)
                                crashLog("stage=frame_copied width=${proxy.width} height=${proxy.height} rotation=$rotationDegrees")
                            } catch (error: Throwable) {
                                processing.release()
                                closeOnce.close()
                                reportCrash("frame_copy", error, active, mainExecutor, onError)
                                return@setAnalyzer
                            }
                            if (firstFrameLogged.compareAndSet(false, true)) debug("FACE_REG_FIRST_FRAME", "received=true")
                            crashLog("stage=mlkit_started")
                            try {
                            currentDetector.process(InputImage.fromMediaImage(media, rotationDegrees))
                                .addOnSuccessListener(executor) { faces ->
                                    crashLog("stage=face_detected count=${faces.size}")
                                    debug(
                                        "FACE_REG_FRAME",
                                        "faces=${faces.size} rotation=$rotationDegrees pose=$pose samples=$completed"
                                    )
                                    when {
                                        faces.isEmpty() -> {
                                            debug("FACE_REG_FRAME", "validation=NO_FACE pose=$pose")
                                            postIfActive(active, mainExecutor) { onGuidance("Mire directamente a la cámara") }
                                        }
                                        faces.size > 1 -> {
                                            debug("FACE_REG_FRAME", "validation=MULTIPLE_FACES pose=$pose")
                                            postIfActive(active, mainExecutor) { onGuidance("Centre un \u00FAnico rostro") }
                                        }
                                        else -> try {
                                            withFrameBitmap(luma, proxy.width, proxy.height, rotationDegrees) { frameBitmap ->
                                            val face = faces.single()
                                            val bounds = face.boundingBox
                                            crashLog("stage=face_cropped bounds=${bounds.width()}x${bounds.height()}")
                                            val quality = frameBitmap.qualityIssue()
                                            debug(
                                                "FACE_REG_FRAME",
                                                "x=${face.headEulerAngleX} y=${face.headEulerAngleY} " +
                                                    "z=${face.headEulerAngleZ} pose=$pose samples=$completed"
                                            )
                                            when {
                                                bounds.width() < frameBitmap.width / 4 || bounds.height() < frameBitmap.height / 4 -> {
                                                    debug("FACE_REG_FRAME", "validation=FACE_TOO_SMALL pose=$pose")
                                                    postIfActive(active, mainExecutor) { onGuidance("Ac\u00E9rquese") }
                                                }
                                                bounds.width() > frameBitmap.width * 9 / 10 || bounds.height() > frameBitmap.height * 9 / 10 -> {
                                                    debug("FACE_REG_FRAME", "validation=FACE_TOO_LARGE pose=$pose")
                                                    postIfActive(active, mainExecutor) { onGuidance("Al\u00E9jese") }
                                                }
                                                !bounds.isInside(frameBitmap.width, frameBitmap.height) -> {
                                                    debug("FACE_REG_FRAME", "validation=FACE_NOT_CENTERED pose=$pose")
                                                    postIfActive(active, mainExecutor) { onGuidance("Centre su rostro") }
                                                }
                                                quality != null -> {
                                                    debug("FACE_REG_FRAME", "validation=IMAGE_QUALITY pose=$pose reason=$quality")
                                                    postIfActive(active, mainExecutor) { onGuidance(quality) }
                                                }
                                                System.currentTimeMillis() < nextCaptureAt[0] -> {
                                                    debug("FACE_REG_FRAME", "validation=SAMPLE_COOLDOWN pose=$pose")
                                                    Unit
                                                }
                                                else -> {
                                                    val embedding = currentEngine.embedding(frameBitmap, Rect(bounds))
                                                    require(embedding.size == FaceEmbeddingEngine.EMBEDDING_DIMENSION) { "invalid_embedding_dimension" }
                                                    crashLog("stage=embedding_generated dimension=${embedding.size}")
                                                    postIfActive(active, mainExecutor) {
                                                        val accepted = onPoseSample(face.headEulerAngleY, face.headEulerAngleX, face.headEulerAngleZ, embedding)
                                                        debug("FACE_REGISTRATION_POSE", "pose=$pose validation=${if (accepted) "READY" else "POSE_NOT_REACHED"}")
                                                        if (accepted) nextCaptureAt[0] = System.currentTimeMillis() + CAPTURE_COOLDOWN_MS
                                                    }
                                                }
                                            }
                                            }
                                        } catch (error: Throwable) {
                                            reportCrash("face_processing", error, active, mainExecutor, onError)
                                        }
                                    }
                                }
                                .addOnFailureListener(executor) { reportCrash("mlkit", it, active, mainExecutor, onError) }
                                .addOnCompleteListener {
                                    processing.release()
                                    closeOnce.close()
                                }
                            } catch (error: Throwable) {
                                processing.release()
                                closeOnce.close()
                                reportCrash("mlkit_start", error, active, mainExecutor, onError)
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
                        reportCrash("camera_setup", error, active, mainExecutor, onError)
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

private fun ByteArray.toBitmap(width: Int, height: Int): Bitmap {
    require(size == width * height) { "invalid_luma_size" }
    val pixels = IntArray(size) { index ->
        val luminance = this[index].toInt() and 0xff
        android.graphics.Color.rgb(luminance, luminance, luminance)
    }
    return Bitmap.createBitmap(pixels, width, height, Bitmap.Config.ARGB_8888)
}

private inline fun withFrameBitmap(luma: ByteArray, width: Int, height: Int, rotationDegrees: Int, action: (Bitmap) -> Unit) {
    val source = luma.toBitmap(width, height)
    val rotated = source.rotated(rotationDegrees)
    try {
        action(rotated)
    } finally {
        if (rotated !== source) rotated.recycle()
        source.recycle()
    }
}

private fun postIfActive(active: AtomicBoolean, mainExecutor: java.util.concurrent.Executor, action: () -> Unit) {
    if (active.get()) mainExecutor.execute { if (active.get()) action() }
}

private fun reportCrash(stage: String, error: Throwable, active: AtomicBoolean, mainExecutor: java.util.concurrent.Executor, onError: (Throwable) -> Unit) {
    Log.e("FACE_REGISTRATION_CRASH", "stage=error file=FaceRegistrationScreen.kt pipelineStage=$stage message=${error.message}", error)
    postIfActive(active, mainExecutor) { onError(error) }
}

private fun crashLog(message: String) {
    if (BuildConfig.DEBUG) Log.d("FACE_REGISTRATION_CRASH", message)
}

private fun debug(tag: String, message: String) {
    if (BuildConfig.DEBUG) Log.d(tag, message)
}

private const val CAPTURE_COOLDOWN_MS = 500L
