package com.example.controlhorario.attendance

import com.example.controlhorario.repository.JourneyCurrentStateOutcome
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class JourneyCurrentStateFallbackPolicyTest {
    @Test fun `pendiente local bloquea cache aunque exista jornada enviada`() {
        assertEquals(
            JourneyCurrentStateOutcome.LOCAL_PENDING,
            JourneyCurrentStateFallbackPolicy.outcome(true,"ENVIADA","2026-07-20","2026-07-20")
        )
    }

    @Test fun `fallo de red usa exclusivamente cache enviada`() {
        assertEquals(
            JourneyCurrentStateOutcome.LOCAL_CACHE,
            JourneyCurrentStateFallbackPolicy.outcome(false,"ENVIADA","2026-07-20","2026-07-20")
        )
        assertNull(JourneyCurrentStateFallbackPolicy.outcome(false,"PENDIENTE","2026-07-20","2026-07-20"))
        assertNull(JourneyCurrentStateFallbackPolicy.outcome(false,"CONFLICTO","2026-07-20","2026-07-20"))
        assertNull(JourneyCurrentStateFallbackPolicy.outcome(false,null,null,"2026-07-20"))
    }

    @Test fun `cache de otro dia nunca habilita acciones`() {
        assertNull(
            JourneyCurrentStateFallbackPolicy.outcome(false,"ENVIADA","2026-07-19","2026-07-20")
        )
    }
}
