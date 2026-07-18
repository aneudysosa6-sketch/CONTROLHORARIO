package com.example.controlhorario.fingerprint.external

import android.app.Activity
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.SystemClock
import android.util.Base64
import android.util.Log
import com.example.controlhorario.BuildConfig
import com.fpreader.fpdevice.UsbReader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class TwoConnectFingerprintManager(
    private val context: Context,
    private val onStatus: (String) -> Unit = {}
) {
    private val appContext = context.applicationContext
    private val hostActivity: Activity? = context.findActivity()
    private val usbManager = appContext.getSystemService(Context.USB_SERVICE) as UsbManager
    private val reader = UsbReader()
    private var matchEngineInitializationAttempted = false
    private var initMatchResult: Boolean? = null
    private var opened = false
    private var receiverRegistered = false
    private val managerInstanceId = System.identityHashCode(this)
    @Volatile
    private var lastVerificationDiagnostics = VerificationDiagnostics()

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                ACTION_USB_PERMISSION -> {
                    val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
                    val device = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
                    when {
                        granted && device != null -> onStatus("Permiso USB concedido para lector 2Connect.")
                        device == null -> onStatus("No se encontró lector 2Connect conectado.")
                        else -> onStatus("Permiso USB denegado para lector 2Connect.")
                    }
                }
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    onStatus("Lector 2Connect conectado. Solicitando permiso USB.")
                    requestUsbPermission()
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    onStatus("Lector 2Connect desconectado.")
                    close()
                }
            }
        }
    }

    init {
        // Demo oficial: new UsbReader -> InitMatch (retorno ignorado) -> SetContextHandler -> OpenDevice.
        initializeMatchEngine()
        val sdkContext = hostActivity ?: context
        reader.SetContextHandler(sdkContext, null)
        registerReceiver()
    }

    fun isSupportedDeviceConnected(): Boolean = findSupportedDevice() != null

    fun hasUsbPermission(): Boolean {
        val device = findSupportedDevice() ?: return false
        return usbManager.hasPermission(device)
    }

    fun isOpen(): Boolean = opened

    fun verificationDiagnostics(): VerificationDiagnostics = lastVerificationDiagnostics

    fun requestUsbPermission(): Boolean {
        val device = findSupportedDevice() ?: return false.also {
            onStatus("Conecte el lector 2Connect USB al teléfono con OTG.")
        }
        if (usbManager.hasPermission(device)) {
            onStatus("Lector 2Connect listo con permiso USB.")
            return true
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val permissionRequestIntent = Intent(ACTION_USB_PERMISSION).apply {
            setPackage(appContext.packageName)
        }
        val permissionIntent = PendingIntent.getBroadcast(appContext, 0, permissionRequestIntent, flags)
        usbManager.requestPermission(device, permissionIntent)
        onStatus("Se solicitó permiso USB para el lector 2Connect.")
        return false
    }

    suspend fun open(): Boolean = withContext(Dispatchers.IO) {
        openReader(attemptId = null)
    }

    private fun openReader(attemptId: Long?): Boolean {
        val startedAt = SystemClock.elapsedRealtime()
        val device = findSupportedDevice()
        if (device == null) {
            logCaptureTrace(attemptId, "OpenDevice:NO_DEVICE", null, startedAt)
            onStatus("No se encontró lector 2Connect USB conectado.")
            return false
        }
        if (!usbManager.hasPermission(device)) {
            logCaptureTrace(attemptId, "OpenDevice:NO_PERMISSION", null, startedAt)
            requestUsbPermission()
            return false
        }
        if (hostActivity == null) {
            logCaptureTrace(attemptId, "OpenDevice:NO_ACTIVITY", null, startedAt)
            onStatus("No se encontró Activity activa para abrir el SDK 2Connect.")
            return false
        }
        if (opened) {
            logCaptureTrace(attemptId, "OpenDevice:ALREADY_OPEN", 0, startedAt)
            return true
        }
        val result = reader.OpenDevice()
        logSdkInit("OpenDevice", result)
        opened = result == 0
        logCaptureTrace(attemptId, "OpenDevice", result, startedAt)
        if (!opened) {
            onStatus("No se pudo abrir el lector 2Connect. Código: $result")
            return false
        }
        onStatus("Lector 2Connect abierto correctamente.")
        return true
    }

    suspend fun enrollFingerprint(debugEmployeeId: Int? = null): CaptureResult = withContext(Dispatchers.IO) {
        hardwareOperationMutex.withLock {
        logMethodEntry("enrollFingerprint", debugEmployeeId)
        if (!open()) {
            logEnrollmentFlow(
                null, null, false, null, null, null, null, 0,
                "READER_OPEN_FAILED", readerOpenedForAttempt = false
            )
            return@withContext CaptureResult.Error("No se pudo abrir el lector 2Connect.")
        }

        onStatus("Coloque el dedo en el lector 2Connect.")
        val first = captureIntoBuffer(attemptId = null, bufferId = 0x01, waitForFinger = true)
        logEnroll("capture=1 imageResult=${first.imageResult} featureGenerationResult=${first.featureGenerationResult}")
        if (!first.success) {
            logEnrollmentTrace(first, null, null, null, null)
            logEnrollmentFlow(first, null, false, null, null, null, null, 0, "CAPTURE_1_FAILED")
            finishEnrollmentAttempt()
            return@withContext CaptureResult.Error(first.message)
        }

        onStatus("Levante el dedo del lector.")
        val fingerLiftDetected = waitForFingerLift()
        if (!fingerLiftDetected) {
            logEnrollmentTrace(first, null, null, null, null)
            logEnrollmentFlow(first, null, false, null, null, null, null, 0, "FINGER_LIFT_NOT_DETECTED")
            finishEnrollmentAttempt()
            return@withContext CaptureResult.Error(
                "No se detectó el retiro del dedo; el registro fue cancelado."
            )
        }

        onStatus("Coloque el mismo dedo nuevamente.")
        val second = captureIntoBuffer(attemptId = null, bufferId = 0x02, waitForFinger = true)
        logEnroll("capture=2 imageResult=${second.imageResult} featureGenerationResult=${second.featureGenerationResult}")
        if (!second.success) {
            logEnrollmentTrace(first, second, null, null, null)
            logEnrollmentFlow(first, second, true, null, null, null, null, 0, "CAPTURE_2_FAILED")
            finishEnrollmentAttempt()
            return@withContext CaptureResult.Error(second.message)
        }

        val regResult = reader.FPRegModule(DEVICE_ADDRESS)
        logEnroll("fpRegModuleResult=$regResult")
        if (regResult != 0) {
            logEnrollmentTrace(first, second, regResult, null, null)
            logEnrollmentFlow(first, second, true, null, regResult, null, null, 0, "REG_MODULE_FAILED")
            finishEnrollmentAttempt()
            return@withContext CaptureResult.Error("No se pudo combinar la plantilla de huella. Código: $regResult")
        }

        val template = ByteArray(REFERENCE_TEMPLATE_BYTES)
        val templateSize = IntArray(1)
        val upResult = reader.FPUpChar(DEVICE_ADDRESS, 0x01, template, templateSize)
        if (upResult != 0 || templateSize[0] <= 0 || templateSize[0] > template.size) {
            logEnrollmentTrace(first, second, regResult, upResult, null)
            logEnrollmentFlow(first, second, true, null, regResult, upResult, null, 0, "UP_CHAR_FAILED")
            finishEnrollmentAttempt()
            return@withContext CaptureResult.Error("No se pudo leer la plantilla registrada. Código: $upResult")
        }

        val cleanTemplate = template.copyOf(templateSize[0])
        logEnrollmentTrace(first, second, regResult, upResult, cleanTemplate)
        FingerprintTemplateDiagnostics.log("A_AFTER_FPUPCHAR", debugEmployeeId, cleanTemplate)
        val encodedTemplate = Base64.encodeToString(cleanTemplate, Base64.NO_WRAP)
        FingerprintTemplateDiagnostics.log("B_BEFORE_ROOM_BASE64", debugEmployeeId, cleanTemplate)
        if (debugEmployeeId != null && BuildConfig.DEBUG) {
            FingerprintDebugTemplateProbe.recordRegistration(debugEmployeeId, cleanTemplate)
        }
        logEnroll(
            "templateBytes=${cleanTemplate.size} base64Length=${encodedTemplate.length} " +
                "fpUpCharResult=$upResult sdkReportedTemplateSize=${templateSize[0]}"
        )
        onStatus("Huella capturada correctamente desde lector 2Connect.")
        val result = CaptureResult.Success(
            templateBase64 = encodedTemplate,
            templateSize = cleanTemplate.size,
            score = null
        )
        logEnrollmentFlow(
            first,
            second,
            fingerLiftDetected,
            null,
            regResult,
            upResult,
            cleanTemplate,
            cleanTemplate.size,
            "CAPTURE_READY_FOR_ROOM_SAVE"
        )
        finishEnrollmentAttempt()
        result
        }
    }

    suspend fun captureTemplateForVerification(
        debugEmployeeId: Int? = null,
        attemptId: Long? = null
    ): CaptureResult = withContext(Dispatchers.IO) {
        hardwareOperationMutex.withLock {
        if (!openReader(attemptId)) {
            return@withContext CaptureResult.Error(
                message = "No se pudo abrir el lector 2Connect.",
                readerOpened = opened,
                initMatchResult = initMatchResult
            )
        }
        onStatus("Coloque el dedo para verificar.")
        val capture = captureIntoBuffer(attemptId, bufferId = 0x01, waitForFinger = true)
        if (!capture.success) {
            return@withContext CaptureResult.Error(
                message = capture.message,
                readerOpened = true,
                imageResult = capture.imageResult,
                featureGenerationResult = capture.featureGenerationResult
            )
        }

        // El demo oficial descarga en un buffer de 512; la plantilla de comparación
        // binaria ocupa los primeros 256 bytes y se entrega así a MatchTemplate.
        val template = ByteArray(REFERENCE_TEMPLATE_BYTES)
        val templateSize = IntArray(1)
        val exportStartedAt = SystemClock.elapsedRealtime()
        val upResult = reader.FPUpChar(DEVICE_ADDRESS, 0x01, template, templateSize)
        logCaptureTrace(attemptId, "FPUpChar:0x01", upResult, exportStartedAt)
        if (upResult != 0 || templateSize[0] <= 0 || templateSize[0] > template.size) {
            return@withContext CaptureResult.Error(
                message = "No se pudo leer la plantilla de verificación. Código: $upResult",
                readerOpened = true,
                imageResult = capture.imageResult,
                featureGenerationResult = capture.featureGenerationResult,
                templateDownloadResult = upResult,
                sdkReportedTemplateSize = templateSize[0],
                initMatchResult = initMatchResult
            )
        }

        val cleanTemplate = template.copyOf(templateSize[0])
        FingerprintTemplateDiagnostics.log("VERIFY_AFTER_FPUPCHAR", debugEmployeeId, cleanTemplate)
        CaptureResult.Success(
            templateBase64 = Base64.encodeToString(cleanTemplate, Base64.NO_WRAP),
            templateSize = cleanTemplate.size,
            score = null,
            readerOpened = true,
            imageResult = capture.imageResult,
            featureGenerationResult = capture.featureGenerationResult,
                templateDownloadResult = upResult,
                sdkReportedTemplateSize = templateSize[0],
                nonZeroByteCount = cleanTemplate.count { it.toInt() != 0 },
                initMatchResult = initMatchResult
        )
        }
    }

    fun verifyCapturedTemplate(
        debugEmployeeId: Int,
        storedTemplateBase64: String,
        storedTemplateSize: Int,
        capture: CaptureResult
    ): FingerprintVerificationResult {
        logMethodEntry("verifyFingerprint", debugEmployeeId)
        val initialDiagnostics = VerificationDiagnostics(
            usbConnected = isSupportedDeviceConnected(),
            usbPermissionGranted = hasUsbPermission(),
            readerOpened = capture.readerOpened,
            imageResult = capture.imageResult,
            featureGenerationResult = capture.featureGenerationResult,
            templateDownloadResult = capture.templateDownloadResult,
            sdkReportedCapturedSize = capture.sdkReportedTemplateSize,
            initMatchResult = capture.initMatchResult ?: initMatchResult,
            initMatchInvoked = matchEngineInitializationAttempted,
            capturedSize = capture.templateSize,
            capturedNonZeroBytes = capture.nonZeroByteCount,
            storedBase64Length = storedTemplateBase64.length,
            uiMessage = capture.message
        )
        if (storedTemplateBase64.isBlank() || storedTemplateSize <= 0) {
            lastVerificationDiagnostics = initialDiagnostics.copy(failure = "MissingStoredTemplate")
            return FingerprintVerificationResult.MissingTemplate
        }

        return try {
            val stored = Base64.decode(storedTemplateBase64, Base64.NO_WRAP)
            val diagnostics = initialDiagnostics.copy(
                storedSize = stored.size,
                storedNonZeroBytes = stored.count { it.toInt() != 0 }
            )
            if (stored.size != storedTemplateSize || stored.size != REFERENCE_TEMPLATE_BYTES || stored.none { it.toInt() != 0 }) {
                lastVerificationDiagnostics = diagnostics.copy(failure = "InvalidStoredTemplate")
                return FingerprintVerificationResult.DeviceError("La plantilla registrada no es válida.")
            }
            if (!capture.success) {
                lastVerificationDiagnostics = diagnostics.copy(failure = "CaptureFailed")
                return FingerprintVerificationResult.CaptureError(
                    "No se pudo leer la huella. Coloque el dedo nuevamente."
                )
            }
            if (!matchEngineInitializationAttempted) {
                lastVerificationDiagnostics = diagnostics.copy(failure = "MatchEngineNotInvoked")
                return FingerprintVerificationResult.DeviceError(
                    "No se ejecutó InitMatch en el lector 2Connect."
                )
            }
            val captured = Base64.decode(capture.templateBase64, Base64.NO_WRAP)
            val templatesDiagnostics = diagnostics.copy(
                capturedSize = captured.size,
                capturedNonZeroBytes = captured.count { it.toInt() != 0 }
            )
            if (
                captured.size != capture.templateSize ||
                !FingerprintVerificationPolicy.shouldExecuteMatch(stored, captured)
            ) {
                lastVerificationDiagnostics = templatesDiagnostics.copy(failure = "InvalidCapturedTemplate")
                FingerprintVerificationResult.CaptureError(
                    "No se pudo leer la huella. Coloque el dedo nuevamente."
                )
            } else {
                // El demo 2Connect usa referencia (512) primero y captura (256) después.
                try {
                    FingerprintTemplateDiagnostics.log("E_BEFORE_MATCH", debugEmployeeId, stored)
                    FingerprintTemplateDiagnostics.log("VERIFY_BEFORE_MATCH", debugEmployeeId, captured)
                    logMatchTrace(stored, captured, score = null, decision = "PENDING")
                    val score = reader.MatchTemplate(stored, captured)
                    val result = FingerprintVerificationPolicy.resultForOfficialScore(
                        score = score,
                        threshold = VERIFIED_MATCH_THRESHOLD
                    )
                    lastVerificationDiagnostics = templatesDiagnostics.copy(
                        matchTemplateExecuted = true,
                        score = score,
                        decision = if (result is FingerprintVerificationResult.Match) "MATCH" else "NO_MATCH"
                    )
                    logMatchTrace(
                        stored,
                        captured,
                        score,
                        if (result is FingerprintVerificationResult.Match) "MATCH" else "NO_MATCH"
                    )
                    result
                } catch (_: Exception) {
                    lastVerificationDiagnostics = templatesDiagnostics.copy(
                        matchTemplateExecuted = false,
                        failure = "MatchExecutionFailed"
                    )
                    FingerprintVerificationResult.DeviceError("No se pudo ejecutar la comparación biométrica.")
                }
            }
        } catch (_: IllegalArgumentException) {
            lastVerificationDiagnostics = initialDiagnostics.copy(failure = "InvalidStoredTemplate")
            FingerprintVerificationResult.DeviceError("La plantilla registrada no es válida.")
        } catch (_: Exception) {
            lastVerificationDiagnostics = initialDiagnostics.copy(failure = "VerificationFailed")
            FingerprintVerificationResult.DeviceError("No se pudo verificar la huella.")
        }
    }

    private fun logEnrollmentTrace(
        first: InternalCaptureResult,
        second: InternalCaptureResult?,
        fpRegModuleResult: Int?,
        fpUpCharResult: Int?,
        template: ByteArray?
    ) {
        if (!BuildConfig.DEBUG) return
        val summary = template?.let(FingerprintTemplateDiagnostics::summarize)
        val templateHash = summary?.sha256 ?: "none"
        Log.d(
            "FINGERPRINT_ENROLL_TRACE",
            "image1Result=${first.imageResult} genChar1Result=${first.featureGenerationResult} " +
                "image2Result=${second?.imageResult} genChar2Result=${second?.featureGenerationResult} " +
                "fpRegModuleResult=$fpRegModuleResult fpUpCharResult=$fpUpCharResult " +
                "templateSize=${summary?.size ?: 0} templateHash=$templateHash"
        )
    }

    private fun logEnrollmentFlow(
        first: InternalCaptureResult?,
        second: InternalCaptureResult?,
        fingerLiftDetected: Boolean,
        sampleMatchScore: Int?,
        fpRegModuleResult: Int?,
        fpUpCharResult: Int?,
        template: ByteArray?,
        templateSize: Int,
        finalResult: String,
        readerOpenedForAttempt: Boolean = true
    ) {
        if (!BuildConfig.DEBUG) return
        Log.d(
            "FINGERPRINT_ENROLL_FLOW",
            "operation=CREATE_OR_UPDATE readerOpenedForAttempt=$readerOpenedForAttempt " +
                "image1Result=${first?.imageResult} genChar1Result=${first?.featureGenerationResult} " +
                "fingerLiftDetected=$fingerLiftDetected image2Result=${second?.imageResult} " +
                "genChar2Result=${second?.featureGenerationResult} sampleMatchScore=$sampleMatchScore " +
                "fpRegModuleResult=$fpRegModuleResult fpUpCharResult=$fpUpCharResult " +
                "templateSize=$templateSize roomSaveExecuted=delegated_to_view_model finalResult=$finalResult"
        )
    }

    private fun finishEnrollmentAttempt() {
        if (opened) {
            val startedAt = SystemClock.elapsedRealtime()
            val result = reader.CloseDevice()
            logCaptureTrace(null, "CloseDevice:enrollment", result, startedAt)
            opened = false
        }
    }

    fun close() {
        if (opened) {
            val startedAt = SystemClock.elapsedRealtime()
            val result = reader.CloseDevice()
            logCaptureTrace(null, "CloseDevice", result, startedAt)
            opened = false
        }
    }

    /**
     * El demo oficial llama InitMatch una vez al crear UsbReader y no evalúa su booleano.
     * El bytecode de fplib-reader-v3 descarta el retorno nativo y retorna false siempre.
     */
    private fun initializeMatchEngine() {
        if (!matchEngineInitializationAttempted) {
            matchEngineInitializationAttempted = true
            initMatchResult = reader.InitMatch()
            logSdkInit("InitMatch", initMatchResult)
            logCaptureTrace(null, "InitMatch", if (initMatchResult == true) 0 else null, SystemClock.elapsedRealtime())
        }
    }

    private fun logSdkInit(operation: String, result: Any?) {
        if (!BuildConfig.DEBUG) return
        val readerHash = System.identityHashCode(reader)
        Log.d(
            "SDK_INIT",
            "operation=$operation result=$result readerHash=$readerHash " +
                "objetoUsbReaderHash=$readerHash thread=${Thread.currentThread().name}"
        )
    }

    private fun logMethodEntry(method: String, employeeId: Int?) {
        Log.i(
            "FINGERPRINT_METHOD_ENTRY",
            "method=$method employeeId=${employeeId ?: "unknown"} " +
                "managerInstance=${System.identityHashCode(this)} thread=${Thread.currentThread().name} " +
                "readerConnected=${isSupportedDeviceConnected()} timestamp=${System.currentTimeMillis()}"
        )
    }

    private fun logEnroll(message: String) {
        if (BuildConfig.DEBUG) {
            Log.d("FINGERPRINT_ENROLL", message)
        }
    }

    private fun logMatchTrace(
        reference: ByteArray,
        candidate: ByteArray,
        score: Int?,
        decision: String
    ) {
        if (!BuildConfig.DEBUG) return
        val referenceSummary = FingerprintTemplateDiagnostics.summarize(reference)
        val candidateSummary = FingerprintTemplateDiagnostics.summarize(candidate)
        Log.d(
            "FINGERPRINT_MATCH_TRACE",
            "referenceSize=${referenceSummary.size} candidateSize=${candidateSummary.size} " +
                "referenceHash=${referenceSummary.sha256} candidateHash=${candidateSummary.sha256} " +
                "argumentOrder=reference,candidate score=$score threshold=$VERIFIED_MATCH_THRESHOLD " +
                "decision=$decision"
        )
    }

    fun release() {
        close()
        if (receiverRegistered) {
            runCatching { appContext.unregisterReceiver(usbReceiver) }
            receiverRegistered = false
        }
    }

    private suspend fun captureIntoBuffer(
        attemptId: Long?,
        bufferId: Int,
        waitForFinger: Boolean
    ): InternalCaptureResult {
        val timeoutAt = System.currentTimeMillis() + CAPTURE_TIMEOUT_MS
        var lastImageResult: Int? = null
        while (System.currentTimeMillis() < timeoutAt) {
            val imageStartedAt = SystemClock.elapsedRealtime()
            val getImageResult = reader.FxGetImage(DEVICE_ADDRESS)
            logCaptureTrace(attemptId, "FxGetImage", getImageResult, imageStartedAt)
            lastImageResult = getImageResult
            if (getImageResult == 0) {
                val generationStartedAt = SystemClock.elapsedRealtime()
                val genResult = reader.FxGenChar(DEVICE_ADDRESS, bufferId)
                logCaptureTrace(attemptId, "GenChar:0x${bufferId.toString(16)}", genResult, generationStartedAt)
                return if (genResult == 0) {
                    InternalCaptureResult(true, "Captura correcta.", getImageResult, genResult)
                } else {
                    InternalCaptureResult(false, "No se pudo generar la plantilla. Código: $genResult", getImageResult, genResult)
                }
            }
            if (!waitForFinger) return InternalCaptureResult(false, "No se detectó dedo en el lector.", getImageResult, null)
            delay(CAPTURE_RETRY_DELAY_MS)
        }
        return InternalCaptureResult(false, "Tiempo agotado esperando la huella en el lector 2Connect.", lastImageResult, null)
    }

    private fun logCaptureTrace(
        attemptId: Long?,
        step: String,
        returnCode: Int?,
        startedAt: Long
    ) {
        if (!BuildConfig.DEBUG) return
        Log.d(
            "FINGERPRINT_CAPTURE_TRACE",
            "attemptId=${attemptId ?: "none"} step=$step returnCode=${returnCode ?: "n/a"} " +
                "readerOpen=$opened usbConnected=${isSupportedDeviceConnected()} " +
                "usbPermission=${hasUsbPermission()} thread=${Thread.currentThread().name} " +
                "elapsedMs=${SystemClock.elapsedRealtime() - startedAt} managerInstance=$managerInstanceId"
        )
    }

    /** Uses the same SDK polling already used by enrollment to wait for finger removal. */
    suspend fun waitForFingerLift(): Boolean = withContext(Dispatchers.IO) {
        val timeoutAt = System.currentTimeMillis() + LIFT_TIMEOUT_MS
        while (System.currentTimeMillis() < timeoutAt) {
            if (reader.FxGetImage(DEVICE_ADDRESS) != 0) return@withContext true
            delay(CAPTURE_RETRY_DELAY_MS)
        }
        false
    }

    private fun findSupportedDevice(): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull { device ->
            SUPPORTED_USB_IDS.any { it.vendorId == device.vendorId && it.productId == device.productId }
        }
    }

    private fun registerReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(ACTION_USB_PERMISSION).apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            appContext.registerReceiver(usbReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            appContext.registerReceiver(usbReceiver, filter)
        }
        receiverRegistered = true
    }

    data class CaptureResult private constructor(
        val success: Boolean,
        val templateBase64: String,
        val templateSize: Int,
        val score: Int?,
        val message: String,
        val readerOpened: Boolean,
        val imageResult: Int?,
        val featureGenerationResult: Int?,
        val templateDownloadResult: Int?,
        val sdkReportedTemplateSize: Int,
        val nonZeroByteCount: Int,
        val initMatchResult: Boolean?
    ) {
        companion object {
            fun Success(
                templateBase64: String,
                templateSize: Int,
                score: Int?,
                readerOpened: Boolean = false,
                imageResult: Int? = null,
                featureGenerationResult: Int? = null,
                templateDownloadResult: Int? = null,
                sdkReportedTemplateSize: Int = templateSize,
                nonZeroByteCount: Int = 0,
                initMatchResult: Boolean? = null
            ) = CaptureResult(
                success = true,
                templateBase64 = templateBase64,
                templateSize = templateSize,
                score = score,
                message = "OK",
                readerOpened = readerOpened,
                imageResult = imageResult,
                featureGenerationResult = featureGenerationResult,
                templateDownloadResult = templateDownloadResult,
                sdkReportedTemplateSize = sdkReportedTemplateSize,
                nonZeroByteCount = nonZeroByteCount,
                initMatchResult = initMatchResult
            )

            fun Error(
                message: String,
                readerOpened: Boolean = false,
                imageResult: Int? = null,
                featureGenerationResult: Int? = null,
                templateDownloadResult: Int? = null,
                sdkReportedTemplateSize: Int = 0,
                initMatchResult: Boolean? = null
            ) = CaptureResult(
                success = false,
                templateBase64 = "",
                templateSize = 0,
                score = null,
                message = message,
                readerOpened = readerOpened,
                imageResult = imageResult,
                featureGenerationResult = featureGenerationResult,
                templateDownloadResult = templateDownloadResult,
                sdkReportedTemplateSize = sdkReportedTemplateSize,
                nonZeroByteCount = 0,
                initMatchResult = initMatchResult
            )
        }
    }

    data class VerificationDiagnostics(
        val usbConnected: Boolean = false,
        val usbPermissionGranted: Boolean = false,
        val readerOpened: Boolean = false,
        val imageResult: Int? = null,
        val featureGenerationResult: Int? = null,
        val templateDownloadResult: Int? = null,
        val sdkReportedCapturedSize: Int = 0,
        val initMatchResult: Boolean? = null,
        val initMatchInvoked: Boolean = false,
        val capturedSize: Int = 0,
        val capturedNonZeroBytes: Int = 0,
        val storedSize: Int = 0,
        val storedBase64Length: Int = 0,
        val storedNonZeroBytes: Int = 0,
        val matchTemplateExecuted: Boolean = false,
        val score: Int? = null,
        val decision: String? = null,
        val failure: String? = null,
        val uiMessage: String = ""
    )

    private data class InternalCaptureResult(
        val success: Boolean,
        val message: String,
        val imageResult: Int?,
        val featureGenerationResult: Int?
    )

    private data class UsbId(val vendorId: Int, val productId: Int)

    companion object {
        private val hardwareOperationMutex = Mutex()
        private const val ACTION_USB_PERMISSION = "com.example.controlhorario.USB_2CONNECT_PERMISSION"
        private const val DEVICE_ADDRESS = -1
        private const val CAPTURE_TIMEOUT_MS = 20_000L
        private const val LIFT_TIMEOUT_MS = 10_000L
        private const val CAPTURE_RETRY_DELAY_MS = 80L
        private const val REFERENCE_TEMPLATE_BYTES = 512
        private const val ENABLE_CANDIDATE_SIZE_DIAGNOSTICS = true
        // Manual/demostración Android 2Connect: MatchTemplate es Match solo si score > 100.
        private const val VERIFIED_MATCH_THRESHOLD = 100
        private val SUPPORTED_USB_IDS = listOf(
            UsbId(0x0453, 0x9005),
            UsbId(0x2009, 0x7638),
            UsbId(0x2109, 0x7638),
            UsbId(0x0483, 0x5720)
        )
    }
}

class UsbPermissionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        // El permiso real se procesa en el receiver dinámico registrado por TwoConnectFingerprintManager.
        // Esta clase existe para que Android 14/15 reciba un PendingIntent explícito y seguro.
    }
}

private tailrec fun Context.findActivity(): Activity? {
    return when (this) {
        is Activity -> this
        is ContextWrapper -> baseContext.findActivity()
        else -> null
    }
}
