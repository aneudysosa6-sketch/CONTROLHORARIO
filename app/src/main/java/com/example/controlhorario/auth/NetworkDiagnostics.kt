package com.example.controlhorario.auth

import android.os.NetworkOnMainThreadException
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.net.ConnectException
import java.net.MalformedURLException
import java.net.SocketTimeoutException
import java.net.URI
import java.net.UnknownHostException
import javax.net.ssl.SSLException

data class SupabaseRuntimeConfig(
    val baseUrl: String,
    val host: String,
    val publishableKey: String,
) {
    companion object {
        fun validate(rawUrl: String, rawKey: String): SupabaseRuntimeConfig {
            val url = rawUrl.trim().trimEnd('/')
            val uri = try { URI(url) } catch (error: Exception) {
                throw AuthFlowException("configuration", "INVALID_SUPABASE_URL", "La URL de Supabase no es válida.", cause = error)
            }
            if (uri.scheme != "https") throw AuthFlowException("configuration", "HTTPS_REQUIRED", "Supabase Auth debe usar HTTPS.")
            if (uri.host.isNullOrBlank()) throw AuthFlowException("configuration", "INVALID_SUPABASE_HOST", "La URL de Supabase no contiene un host válido.")
            val key = rawKey.trim()
            if (key.isBlank()) throw AuthFlowException("configuration", "PUBLISHABLE_KEY_EMPTY", "La clave publicable de Supabase está vacía.")
            if (!key.startsWith("sb_publishable_") && !key.startsWith("eyJ")) throw AuthFlowException("configuration", "PUBLISHABLE_KEY_INVALID", "La clave publicable de Supabase tiene un formato inválido.")
            if (key.startsWith("sb_publishable_") && key.length < 32) throw AuthFlowException("configuration", "PUBLISHABLE_KEY_TRUNCATED", "La clave publicable de Supabase parece estar truncada.")
            return SupabaseRuntimeConfig(url, uri.host, key)
        }
    }
}

data class ClassifiedNetworkFailure(val code: String, val type: String, val message: String)

object NetworkFailureClassifier {
    fun classify(error: Throwable): ClassifiedNetworkFailure {
        val chain = generateSequence(error as Throwable?) { it.cause }.toList()
        val match = chain.firstOrNull { it is NetworkOnMainThreadException || it is UnknownHostException || it is SSLException || it is SocketTimeoutException || it is ConnectException || it is MalformedURLException }
        return when (match) {
            is NetworkOnMainThreadException -> ClassifiedNetworkFailure("NETWORK_ON_MAIN_THREAD", "hilo principal", "La llamada de red se ejecutó en el hilo principal.")
            is UnknownHostException -> ClassifiedNetworkFailure("DNS_ERROR", "DNS", match.message ?: "No fue posible resolver el host.")
            is SSLException -> ClassifiedNetworkFailure("TLS_ERROR", "TLS", match.message ?: "Falló la negociación TLS.")
            is SocketTimeoutException -> ClassifiedNetworkFailure("TIMEOUT", "timeout", match.message ?: "La conexión agotó el tiempo de espera.")
            is ConnectException -> ClassifiedNetworkFailure("CONNECTION_REFUSED", "conexión rechazada", match.message ?: "El servidor rechazó la conexión.")
            is MalformedURLException -> ClassifiedNetworkFailure("INVALID_URL", "configuración", match.message ?: "La URL no es válida.")
            else -> ClassifiedNetworkFailure("NETWORK_ERROR", error::class.java.simpleName, error.message ?: "Error de red no identificado.")
        }
    }
}

object SafeHttpDiagnostics {
    private val secretKeys = Regex("token|password|credential|authorization|apikey|secret", RegexOption.IGNORE_CASE)

    fun request(tag: String, method: String, url: String, config: SupabaseRuntimeConfig) {
        Log.i(tag, "request_method=$method; url=$url; host=${config.host}; https=${url.startsWith("https://")}; publishable_key_present=${config.publishableKey.isNotBlank()}; publishable_key_length=${config.publishableKey.length}")
    }

    fun response(tag: String, status: Int, body: String) {
        Log.i(tag, "http_status=$status")
        logChunks(tag, "response_body=${sanitize(body)}")
    }

    fun exception(tag: String, stage: String, error: Throwable): ClassifiedNetworkFailure {
        val classified = NetworkFailureClassifier.classify(error)
        Log.e(tag, "stage=$stage; network_type=${classified.type}; code=${classified.code}; exception=${error::class.java.name}; message=${classified.message}", error)
        return classified
    }

    fun sanitize(body: String): String {
        if (body.isBlank()) return "<empty>"
        return runCatching {
            val trimmed = body.trim()
            when {
                trimmed.startsWith("{") -> redact(JSONObject(trimmed)).toString()
                trimmed.startsWith("[") -> redact(JSONArray(trimmed)).toString()
                else -> trimmed
            }
        }.getOrElse { body }
    }

    private fun redact(value: JSONObject): JSONObject = JSONObject().also { output ->
        value.keys().forEach { key -> output.put(key, if (secretKeys.containsMatchIn(key)) "[REDACTED]" else redactValue(value.opt(key))) }
    }
    private fun redact(value: JSONArray): JSONArray = JSONArray().also { output -> repeat(value.length()) { output.put(redactValue(value.opt(it))) } }
    private fun redactValue(value: Any?): Any? = when (value) { is JSONObject -> redact(value); is JSONArray -> redact(value); else -> value }
    private fun logChunks(tag: String, value: String) { value.chunked(3_000).forEachIndexed { index, chunk -> Log.i(tag, "body_chunk=${index + 1}; $chunk") } }
}
