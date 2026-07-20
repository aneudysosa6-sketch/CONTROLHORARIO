package com.example.controlhorario.ui.punch

import com.example.controlhorario.database.JourneyEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JourneyRemotePresentationTest {
    @Test fun `loading never enables journey actions`() {
        val state = JourneyRemotePresentation.loading()

        assertTrue(state.loadingRemote)
        assertFalse(state.actionsAllowed)
        assertEquals("Sincronizando estado de jornada…", state.message)
    }

    @Test fun `network failure without cache blocks every action`() {
        val state = JourneyRemotePresentation.networkFailure(null)

        assertFalse(state.loadingRemote)
        assertFalse(state.actionsAllowed)
        assertEquals(
            "No se pudo confirmar el estado actual de la jornada. Verifique la conexión.",
            state.message
        )
    }

    @Test fun `network failure accepts a previously synchronized local journey`() {
        val cached = journey(syncStatus = "ENVIADA", status = "EN_CURSO")

        val state = JourneyRemotePresentation.networkFailure(cached)

        assertEquals(JourneyRemoteAccess.CACHED, state.access)
        assertTrue(state.actionsAllowed)
    }

    @Test fun `pending local journey is not considered a valid cache`() {
        val pending = journey(syncStatus = "PENDIENTE", status = "EN_CURSO")

        val state = JourneyRemotePresentation.networkFailure(pending)

        assertEquals(JourneyRemoteAccess.BLOCKED, state.access)
        assertFalse(state.actionsAllowed)
    }

    @Test fun `pending and conflict outcomes stay blocked`() {
        assertFalse(JourneyRemotePresentation.pendingLocalAction().actionsAllowed)
        assertFalse(JourneyRemotePresentation.conflict().actionsAllowed)
    }

    private fun journey(syncStatus: String, status: String) = JourneyEntity(
        employeeLocalId = 4,
        employeeRemoteId = "11111111-1111-1111-1111-111111111111",
        deviceId = "22222222-2222-2222-2222-222222222222",
        workDate = "2026-07-20",
        status = status,
        syncStatus = syncStatus
    )
}
