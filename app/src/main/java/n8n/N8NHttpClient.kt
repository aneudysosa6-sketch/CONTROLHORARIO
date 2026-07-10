package com.example.controlhorario.n8n

import com.example.controlhorario.database.N8NSettingsEntity
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

object N8NHttpClient {
    data class Result(
        val success: Boolean,
        val code: Int,
        val message: String,
        val body: String = ""
    )

    fun post(settings: N8NSettingsEntity, payloadJson: String): Result {
        val urlText = settings.webhookUrl.trim()
        if (urlText.isBlank()) {
            return Result(false, 0, "Webhook N8N no configurado")
        }
        return try {
            val connection = (URL(urlText).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                connectTimeout = (settings.timeoutSeconds.coerceAtLeast(5)) * 1000
                readTimeout = (settings.timeoutSeconds.coerceAtLeast(5)) * 1000
                doOutput = true
                setRequestProperty("Content-Type", "application/json; charset=utf-8")
                setRequestProperty("Accept", "application/json")
                if (settings.apiKey.isNotBlank()) {
                    setRequestProperty("X-API-Key", settings.apiKey.trim())
                }
                if (settings.bearerToken.isNotBlank()) {
                    setRequestProperty("Authorization", "Bearer ${settings.bearerToken.trim()}")
                }
            }
            OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(payloadJson)
                writer.flush()
            }
            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val body = stream?.let { input ->
                BufferedReader(InputStreamReader(input, Charsets.UTF_8)).use { reader -> reader.readText() }
            }.orEmpty()
            connection.disconnect()
            Result(code in 200..299, code, if (code in 200..299) "Conectado" else "Respuesta HTTP $code", body)
        } catch (e: Exception) {
            Result(false, 0, e.message ?: "Error de conexión con N8N")
        }
    }
}
