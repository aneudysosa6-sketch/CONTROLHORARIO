package com.example.controlhorario.auth

import androidx.test.ext.junit.runners.AndroidJUnit4
import com.example.controlhorario.BuildConfig
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SupabaseNetworkInstrumentedTest {
    @Test fun runtimeApkHasHttpsHostAndPublishableKey() {
        val config = SupabaseRuntimeConfig.validate(BuildConfig.SUPABASE_URL, BuildConfig.SUPABASE_PUBLISHABLE_KEY)
        assertEquals("https", java.net.URI(config.baseUrl).scheme)
        assertTrue(config.host.endsWith(".supabase.co"))
        assertTrue(config.publishableKey.isNotBlank())
    }

    @Test fun apkReachesSupabaseAuthWithoutDnsTlsOrTimeoutFailure() = runBlocking {
        val error = runCatching {
            SupabaseAuthApi().signInWithPassword(
                "codex-nonexistent-apk-test@invalid.example",
                "NotARealCredential-2026",
            )
        }.exceptionOrNull()
        assertTrue(error is AuthFlowException)
        assertEquals("invalid_credentials", (error as AuthFlowException).code)
    }
}
