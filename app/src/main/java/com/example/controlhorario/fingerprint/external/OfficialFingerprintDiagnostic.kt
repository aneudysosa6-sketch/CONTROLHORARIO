package com.example.controlhorario.fingerprint.external

import android.content.Context
import android.os.SystemClock
import android.util.Log
import com.fpreader.fpdevice.UsbReader
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext

/**
 * DEBUG diagnostic copied from the vendor's Test1Activity flow. It deliberately
 * owns its own UsbReader and keeps reference data in memory only; it never reads
 * or writes Room and never participates in attendance authorization.
 */
class OfficialFingerprintDiagnostic(
    context: Context,
    private val onStatus: (String) -> Unit
) {
    // UsbReader.usb_get_device() casts the context supplied here to Activity.
    // Keep the screen context, exactly as the vendor Test1Activity does.
    private val sdkContext = context
    private val reader = UsbReader()
    private var reference: ByteArray? = null

    init {
        reader.InitMatch()
        reader.SetContextHandler(sdkContext, null)
        // Test1Activity calls ResumeRegister(), but the vendor JAR creates its
        // PendingIntent without Android 12+ mutability flags there. The app's
        // production USB-permission receiver already owns that responsibility.
        // Do not enter the obsolete JAR registration path from this temporary
        // in-memory diagnostic.
    }

    suspend fun enrollReference(): Result = withContext(Dispatchers.IO) {
        if (reader.OpenDevice() != 0) return@withContext Result.Error("OpenDevice falló.")
        onStatus("Diagnóstico oficial: coloque el dedo (captura 1).")
        if (!capture(0x01)) return@withContext Result.Error("Falló captura 1 / GenChar(0x01).")
        onStatus("Diagnóstico oficial: retire completamente el dedo.")
        if (!waitFingerLift()) return@withContext Result.Error("No se detectó retiro del dedo.")
        onStatus("Diagnóstico oficial: coloque el mismo dedo (captura 2).")
        if (!capture(0x02)) return@withContext Result.Error("Falló captura 2 / GenChar(0x02).")
        val reg = reader.FPRegModule(DEVICE_ADDRESS)
        if (reg != 0) return@withContext Result.Error("FPRegModule=$reg")
        val refdata = ByteArray(REFERENCE_BYTES)
        val refsize = IntArray(1)
        val up = reader.FPUpChar(DEVICE_ADDRESS, 0x01, refdata, refsize)
        if (up != 0 || refsize[0] != REFERENCE_BYTES) return@withContext Result.Error("FPUpChar referencia=$up size=${refsize[0]}")
        reference = refdata
        Log.d("OFFICIAL_FINGERPRINT_DIAGNOSTIC", "stage=ENROLL refsize=${refsize[0]} buffer=0x01 fpRegModule=$reg fpUpChar=$up")
        Result.Enrolled(refsize[0])
    }

    suspend fun captureAndCompare(): Result = withContext(Dispatchers.IO) {
        val refdata = reference ?: return@withContext Result.Error("Registre primero una referencia en memoria.")
        if (reader.OpenDevice() != 0) return@withContext Result.Error("OpenDevice falló.")
        onStatus("Diagnóstico oficial: coloque el dedo para comparar.")
        if (!capture(0x01)) return@withContext Result.Error("Falló captura / GenChar(0x01).")
        val matdata = ByteArray(REFERENCE_BYTES)
        val matsize = IntArray(1)
        val up = reader.FPUpChar(DEVICE_ADDRESS, 0x01, matdata, matsize)
        if (up != 0) return@withContext Result.Error("FPUpChar coincidencia=$up")
        // Literal Test1Activity: backing buffer is 512, reported matching size is 256.
        matsize[0] = MATCHING_BYTES
        val refRef = reader.MatchTemplate(refdata, refdata)
        val matMat = reader.MatchTemplate(matdata, matdata)
        val score = reader.MatchTemplate(refdata, matdata)
        Log.d(
            "OFFICIAL_FINGERPRINT_DIAGNOSTIC",
            "stage=VERIFY refsize=$REFERENCE_BYTES matsize=${matsize[0]} buffer=0x01 " +
                "fpUpChar=$up refRef=$refRef matMat=$matMat score=$score accepted=${score > 100}"
        )
        Result.Compared(refRef, matMat, score)
    }

    fun release() {
        reader.CloseDevice()
        reader.PauseUnRegister()
    }

    private suspend fun capture(buffer: Int): Boolean {
        val deadline = SystemClock.elapsedRealtime() + CAPTURE_TIMEOUT_MS
        while (SystemClock.elapsedRealtime() < deadline) {
            if (reader.FxGetImage(DEVICE_ADDRESS) == 0) return reader.FxGenChar(DEVICE_ADDRESS, buffer) == 0
            delay(POLL_MS)
        }
        return false
    }

    private suspend fun waitFingerLift(): Boolean {
        val deadline = SystemClock.elapsedRealtime() + CAPTURE_TIMEOUT_MS
        while (SystemClock.elapsedRealtime() < deadline) {
            if (reader.FxGetImage(DEVICE_ADDRESS) != 0) return true
            delay(POLL_MS)
        }
        return false
    }

    sealed class Result {
        data class Enrolled(val referenceSize: Int) : Result()
        data class Compared(val refRef: Int, val matMat: Int, val score: Int) : Result()
        data class Error(val message: String) : Result()
    }

    private companion object {
        const val DEVICE_ADDRESS = -1
        const val REFERENCE_BYTES = 512
        const val MATCHING_BYTES = 256
        const val POLL_MS = 120L
        const val CAPTURE_TIMEOUT_MS = 30_000L
    }
}
