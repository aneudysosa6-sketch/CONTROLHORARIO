package com.example.controlhorario.messages

object EmployeeMessagePolicy {
    private val supportedTypes = setOf("TEXTO", "VOZ_SISTEMA", "VOZ_GRABADA")

    fun isValid(type: String, text: String?, audioUrl: String?, durationSeconds: Int): Boolean {
        if (type !in supportedTypes) return false
        return when (type) {
            "VOZ_GRABADA" ->
                !audioUrl.isNullOrBlank() &&
                    audioUrl.startsWith("https://") &&
                    durationSeconds in 1..30
            else -> !text.isNullOrBlank() && audioUrl == null && durationSeconds == 0
        }
    }

    fun isReceiptAccepted(result: String?): Boolean =
        result?.lowercase() in setOf("accepted", "duplicate", "received", "already_received")
}