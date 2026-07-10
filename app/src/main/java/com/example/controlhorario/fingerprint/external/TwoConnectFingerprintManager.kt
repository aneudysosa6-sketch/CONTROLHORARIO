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
import android.util.Base64
import com.fpreader.fpdevice.UsbReader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

class TwoConnectFingerprintManager(
    private val context: Context,
    private val onStatus: (String) -> Unit = {}
) {
    private val appContext = context.applicationContext
    private val hostActivity: Activity? = context.findActivity()
    private val usbManager = appContext.getSystemService(Context.USB_SERVICE) as UsbManager
    private val reader = UsbReader()
    private var opened = false
    private var receiverRegistered = false

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
        reader.InitMatch()
        val sdkContext = hostActivity ?: context
        reader.SetContextHandler(sdkContext, null)
        registerReceiver()
    }

    fun isSupportedDeviceConnected(): Boolean = findSupportedDevice() != null

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
        val device = findSupportedDevice()
        if (device == null) {
            onStatus("No se encontró lector 2Connect USB conectado.")
            return@withContext false
        }
        if (!usbManager.hasPermission(device)) {
            requestUsbPermission()
            return@withContext false
        }
        if (hostActivity == null) {
            onStatus("No se encontró Activity activa para abrir el SDK 2Connect.")
            return@withContext false
        }
        if (opened) return@withContext true
        val result = reader.OpenDevice()
        opened = result == 0
        onStatus(if (opened) "Lector 2Connect abierto correctamente." else "No se pudo abrir el lector 2Connect. Código: $result")
        opened
    }

    suspend fun enrollFingerprint(): CaptureResult = withContext(Dispatchers.IO) {
        if (!open()) return@withContext CaptureResult.Error("No se pudo abrir el lector 2Connect.")

        onStatus("Coloque el dedo en el lector 2Connect.")
        val first = captureIntoBuffer(bufferId = 0x01, waitForFinger = true)
        if (!first.success) return@withContext CaptureResult.Error(first.message)

        onStatus("Levante el dedo del lector.")
        waitFingerLift()

        onStatus("Coloque el mismo dedo nuevamente.")
        val second = captureIntoBuffer(bufferId = 0x02, waitForFinger = true)
        if (!second.success) return@withContext CaptureResult.Error(second.message)

        val regResult = reader.FPRegModule(DEVICE_ADDRESS)
        if (regResult != 0) {
            return@withContext CaptureResult.Error("No se pudo combinar la plantilla de huella. Código: $regResult")
        }

        val template = ByteArray(512)
        val templateSize = IntArray(1)
        val upResult = reader.FPUpChar(DEVICE_ADDRESS, 0x01, template, templateSize)
        if (upResult != 0 || templateSize[0] <= 0) {
            return@withContext CaptureResult.Error("No se pudo leer la plantilla registrada. Código: $upResult")
        }

        val cleanTemplate = template.copyOf(templateSize[0])
        onStatus("Huella capturada correctamente desde lector 2Connect.")
        CaptureResult.Success(
            templateBase64 = Base64.encodeToString(cleanTemplate, Base64.NO_WRAP),
            templateSize = cleanTemplate.size,
            score = null
        )
    }

    suspend fun captureTemplateForVerification(): CaptureResult = withContext(Dispatchers.IO) {
        if (!open()) return@withContext CaptureResult.Error("No se pudo abrir el lector 2Connect.")

        onStatus("Coloque el dedo para verificar.")
        val capture = captureIntoBuffer(bufferId = 0x01, waitForFinger = true)
        if (!capture.success) return@withContext CaptureResult.Error(capture.message)

        val template = ByteArray(512)
        val templateSize = IntArray(1)
        val upResult = reader.FPUpChar(DEVICE_ADDRESS, 0x01, template, templateSize)
        if (upResult != 0 || templateSize[0] <= 0) {
            return@withContext CaptureResult.Error("No se pudo leer la plantilla de verificación. Código: $upResult")
        }

        val cleanTemplate = template.copyOf(templateSize[0])
        CaptureResult.Success(
            templateBase64 = Base64.encodeToString(cleanTemplate, Base64.NO_WRAP),
            templateSize = cleanTemplate.size,
            score = null
        )
    }

    fun matchTemplates(storedTemplateBase64: String, capturedTemplateBase64: String): Int {
        return try {
            val stored = Base64.decode(storedTemplateBase64, Base64.NO_WRAP)
            val captured = Base64.decode(capturedTemplateBase64, Base64.NO_WRAP)
            reader.MatchTemplate(stored, captured)
        } catch (e: Exception) {
            -1
        }
    }

    fun close() {
        if (opened) {
            reader.CloseDevice()
            opened = false
        }
    }

    fun release() {
        close()
        if (receiverRegistered) {
            runCatching { appContext.unregisterReceiver(usbReceiver) }
            receiverRegistered = false
        }
    }

    private suspend fun captureIntoBuffer(bufferId: Int, waitForFinger: Boolean): InternalCaptureResult {
        val timeoutAt = System.currentTimeMillis() + CAPTURE_TIMEOUT_MS
        while (System.currentTimeMillis() < timeoutAt) {
            val getImageResult = reader.FxGetImage(DEVICE_ADDRESS)
            if (getImageResult == 0) {
                val genResult = reader.FxGenChar(DEVICE_ADDRESS, bufferId)
                return if (genResult == 0) {
                    InternalCaptureResult(true, "Captura correcta.")
                } else {
                    InternalCaptureResult(false, "No se pudo generar la plantilla. Código: $genResult")
                }
            }
            if (!waitForFinger) return InternalCaptureResult(false, "No se detectó dedo en el lector.")
            delay(CAPTURE_RETRY_DELAY_MS)
        }
        return InternalCaptureResult(false, "Tiempo agotado esperando la huella en el lector 2Connect.")
    }

    private suspend fun waitFingerLift() {
        val timeoutAt = System.currentTimeMillis() + LIFT_TIMEOUT_MS
        while (System.currentTimeMillis() < timeoutAt) {
            if (reader.FxGetImage(DEVICE_ADDRESS) != 0) return
            delay(CAPTURE_RETRY_DELAY_MS)
        }
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
        val message: String
    ) {
        companion object {
            fun Success(templateBase64: String, templateSize: Int, score: Int?) = CaptureResult(
                success = true,
                templateBase64 = templateBase64,
                templateSize = templateSize,
                score = score,
                message = "OK"
            )

            fun Error(message: String) = CaptureResult(
                success = false,
                templateBase64 = "",
                templateSize = 0,
                score = null,
                message = message
            )
        }
    }

    private data class InternalCaptureResult(val success: Boolean, val message: String)

    private data class UsbId(val vendorId: Int, val productId: Int)

    companion object {
        private const val ACTION_USB_PERMISSION = "com.example.controlhorario.USB_2CONNECT_PERMISSION"
        private const val DEVICE_ADDRESS = -1
        private const val CAPTURE_TIMEOUT_MS = 20_000L
        private const val LIFT_TIMEOUT_MS = 10_000L
        private const val CAPTURE_RETRY_DELAY_MS = 80L
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
