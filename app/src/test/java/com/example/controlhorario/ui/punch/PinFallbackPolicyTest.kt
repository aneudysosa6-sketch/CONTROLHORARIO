package com.example.controlhorario.ui.punch

import com.example.controlhorario.face.FaceEmbeddingEngine
import com.example.controlhorario.repository.KioskFaceAuthSettings
import com.example.controlhorario.repository.KioskSettingsRepository
import com.example.controlhorario.ui.login.PermissionCatalog
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class PinFallbackPolicyTest {
    private fun settings(enabled: Boolean) = KioskFaceAuthSettings(
        companyId = "company-a",
        deviceId = "device-a",
        faceOnlyEnabled = true,
        pinFallbackEnabled = enabled,
        faceMatchThreshold = FaceEmbeddingEngine.COSINE_THRESHOLD,
        faceMatchMargin = null,
        remoteUpdatedAt = "2026-07-20T12:00:00Z",
        lastSyncedAt = 1L,
    )

    @Test fun `pin fallback disabled is never enabled by policy`() {
        assertFalse(PinFallbackPolicy.isEnabled(settings(enabled = false)))
    }

    @Test fun `pin fallback enabled remains available offline`() {
        assertTrue(PinFallbackPolicy.isEnabled(settings(enabled = true)))
    }

    @Test fun `only exact management permission authorizes changes`() {
        assertFalse(PinFallbackPolicy.canManage(setOf("configuracion.administrar")))
        assertTrue(PinFallbackPolicy.canManage(setOf(PermissionCatalog.KIOSK_PIN_FALLBACK_MANAGE)))
        assertThrows(SecurityException::class.java) { PinFallbackPolicy.requireCanManage(emptySet()) }
    }

    @Test fun `offline defaults preserve current threshold without inventing margin`() {
        val defaults = KioskSettingsRepository.defaults("company-a", "device-a")
        assertEquals(FaceEmbeddingEngine.COSINE_THRESHOLD, defaults.faceMatchThreshold)
        assertNull(defaults.faceMatchMargin)
    }

    @Test fun `invalid remote confidence values are rejected`() {
        assertThrows(IllegalArgumentException::class.java) { KioskSettingsRepository.validate(Float.NaN, null) }
        assertThrows(IllegalArgumentException::class.java) { KioskSettingsRepository.validate(0.75f, -0.01f) }
    }
}
