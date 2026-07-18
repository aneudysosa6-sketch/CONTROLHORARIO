package com.example.controlhorario.fingerprint.external

import android.util.Log
import com.example.controlhorario.BuildConfig
import com.fpreader.fpdevice.UsbReader
import java.security.MessageDigest

data class FingerprintTemplateSummary(
    val size: Int,
    val sha256: String,
    val nonZeroBytes: Int
)

object FingerprintTemplateDiagnostics {
    fun summarize(template: ByteArray): FingerprintTemplateSummary = FingerprintTemplateSummary(
        size = template.size,
        sha256 = MessageDigest.getInstance("SHA-256")
            .digest(template)
            .joinToString("") { "%02x".format(it) },
        nonZeroBytes = template.count { it.toInt() != 0 }
    )

    fun log(stage: String, employeeId: Int?, template: ByteArray) {
        if (!BuildConfig.DEBUG) return
        val summary = summarize(template)
        Log.d(
            "FINGERPRINT_TEMPLATE_TRACE",
            "stage=$stage employeeId=${employeeId ?: "unknown"} size=${summary.size} " +
                "sha256=${summary.sha256} nonZeroBytes=${summary.nonZeroBytes}"
        )
    }
}

/** DEBUG-only transient reference used to compare registration memory against Room. */
object FingerprintDebugTemplateProbe {
    private var employeeId: Int? = null
    private var reference: ByteArray? = null

    fun recordRegistration(employeeId: Int, template: ByteArray) {
        if (!BuildConfig.DEBUG) return
        this.employeeId = employeeId
        reference = template.copyOf()
    }

    fun compare(
        reader: UsbReader,
        employeeId: Int,
        roomReference: ByteArray,
        candidate: ByteArray
    ) {
        if (!BuildConfig.DEBUG) return
        val memoryReference = reference?.takeIf { this.employeeId == employeeId }
        val directMemoryScore = memoryReference?.let { reader.MatchTemplate(it, candidate) }
        val roomLoadedScore = reader.MatchTemplate(roomReference, candidate)
        val memoryHash = memoryReference?.let { FingerprintTemplateDiagnostics.summarize(it).sha256 }
        val roomHash = FingerprintTemplateDiagnostics.summarize(roomReference).sha256
        Log.d(
            "FINGERPRINT_MATCH_TRACE",
            "employeeId=$employeeId directMemoryScore=$directMemoryScore roomLoadedScore=$roomLoadedScore " +
                "memoryReferenceHash=$memoryHash roomReferenceHash=$roomHash"
        )
        reference = null
        this.employeeId = null
    }
}
