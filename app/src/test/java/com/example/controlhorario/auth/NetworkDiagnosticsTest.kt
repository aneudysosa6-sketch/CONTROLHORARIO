package com.example.controlhorario.auth

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.net.ConnectException
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import javax.net.ssl.SSLHandshakeException

class NetworkDiagnosticsTest {
    @Test fun `runtime exige URL HTTPS y conserva host exacto`() {
        val config = SupabaseRuntimeConfig.validate(" https://project.supabase.co/ ", "sb_publishable_12345678901234567890")
        assertEquals("https://project.supabase.co", config.baseUrl)
        assertEquals("project.supabase.co", config.host)
    }

    @Test fun `runtime rechaza HTTP`() {
        val error = runCatching { SupabaseRuntimeConfig.validate("http://project.supabase.co", "sb_publishable_12345678901234567890") }.exceptionOrNull()
        assertEquals("HTTPS_REQUIRED", (error as AuthFlowException).code)
    }

    @Test fun `runtime rechaza clave vacia`() {
        val error = runCatching { SupabaseRuntimeConfig.validate("https://project.supabase.co", "") }.exceptionOrNull()
        assertEquals("PUBLISHABLE_KEY_EMPTY", (error as AuthFlowException).code)
    }

    @Test fun `runtime rechaza clave publicable truncada`() {
        val error = runCatching { SupabaseRuntimeConfig.validate("https://project.supabase.co", "sb_publishable_short") }.exceptionOrNull()
        assertEquals("PUBLISHABLE_KEY_TRUNCATED", (error as AuthFlowException).code)
    }

    @Test fun `clasifica DNS`() = assertEquals("DNS_ERROR", NetworkFailureClassifier.classify(UnknownHostException("host")).code)
    @Test fun `clasifica TLS`() = assertEquals("TLS_ERROR", NetworkFailureClassifier.classify(SSLHandshakeException("certificate")).code)
    @Test fun `clasifica timeout`() = assertEquals("TIMEOUT", NetworkFailureClassifier.classify(SocketTimeoutException("timeout")).code)
    @Test fun `clasifica conexion rechazada`() = assertEquals("CONNECTION_REFUSED", NetworkFailureClassifier.classify(ConnectException("refused")).code)

    @Test fun `clasifica causa anidada sin perder tipo`() {
        val classified = NetworkFailureClassifier.classify(IllegalStateException("wrapper", UnknownHostException("dns")))
        assertEquals("DNS_ERROR", classified.code)
        assertTrue(classified.type.contains("DNS"))
    }
}
