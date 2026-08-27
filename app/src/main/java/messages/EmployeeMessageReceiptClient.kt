package com.example.controlhorario.messages

import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.time.Instant
import java.util.UUID

class EmployeeMessageReceiptClient(private val endpoint: String) {
    fun confirm(deviceId: String, credential: String, messageId: String, employeeRemoteId: String): Boolean {
        require(endpoint.startsWith("https://") && endpoint.endsWith("/functions/v1/attendance-sync"))
        require(runCatching { UUID.fromString(messageId) }.isSuccess)
        require(runCatching { UUID.fromString(employeeRemoteId) }.isSuccess)
        val request = JSONObject()
            .put("mode", "message_receipt")
            .put("message_id", messageId)
            .put("idempotency_key", messageId)
            .put("employee_remote_id", employeeRemoteId)
            .put("received_at", Instant.now().toString())
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 25_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("x-device-id", deviceId)
            setRequestProperty("x-device-credential", credential)
        }
        try {
            connection.outputStream.use { it.write(request.toString().toByteArray()) }
            val status = connection.responseCode
            val body = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw EmployeeMessageReceiptHttpException(status)
            val json = JSONObject(body)
            return json.optBoolean("ok", false) ||
                EmployeeMessagePolicy.isReceiptAccepted(json.optString("result")) ||
                EmployeeMessagePolicy.isReceiptAccepted(json.optString("status"))
        } finally {
            connection.disconnect()
        }
    }
}

class EmployeeMessageReceiptHttpException(val status: Int) :
    Exception("employee-message receipt HTTP $status")
