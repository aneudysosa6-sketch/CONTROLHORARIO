package com.example.controlhorario.database

import org.junit.Assert.assertEquals
import org.junit.Test

class JourneyRemoteHydrationPolicyTest {
    @Test fun `estado remoto crea cache cuando no existe jornada local`() {
        assertEquals(
            JourneyRemoteHydrationDecision.INSERT,
            JourneyRemoteHydrationPolicy.decide(
                local = null,
                hasPendingOutbox = false,
                hasUnresolvedConflict = false,
                remoteVersion = 3
            )
        )
    }

    @Test fun `version remota mas nueva actualiza una jornada sincronizada`() {
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(
                local(syncVersion = 2),
                hasPendingOutbox = false,
                hasUnresolvedConflict = false,
                remoteVersion = 3
            )
        )
    }

    @Test fun `misma version acepta snapshot remoto cuando no hay pendientes`() {
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(
                local(syncVersion = 3),
                hasPendingOutbox = false,
                hasUnresolvedConflict = false,
                remoteVersion = 3
            )
        )
    }

    @Test fun `accion local pendiente nunca es sobrescrita aunque remoto sea mas nuevo`() {
        val pending = local(syncStatus = "PENDIENTE", syncVersion = 2)
        assertEquals(
            JourneyRemoteHydrationDecision.BLOCKED_PENDING,
            JourneyRemoteHydrationPolicy.decide(
                pending,
                hasPendingOutbox = true,
                hasUnresolvedConflict = false,
                remoteVersion = 9
            )
        )
    }

    @Test fun `snapshot remoto es autoritativo sin cambios locales aunque la version cache sea mayor`() {
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(
                local(syncVersion = 8),
                hasPendingOutbox = false,
                hasUnresolvedConflict = false,
                remoteVersion = 7
            )
        )
    }

    @Test fun `conflicto local temporal acepta una version remota mas nueva`() {
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(local(syncStatus = "CONFLICTO", syncVersion = 2), false, false, 3)
        )
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(local(syncStatus = "CONFLICTO", syncVersion = 3), false, false, 3)
        )
    }

    @Test fun `flags locales obsoletos no sustituyen la existencia real del outbox`() {
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(local(syncStatus = "PENDIENTE", syncVersion = 2), false, false, 3)
        )
        assertEquals(
            JourneyRemoteHydrationDecision.BLOCKED_PENDING,
            JourneyRemoteHydrationPolicy.decide(local(syncStatus = "ENVIADA", syncVersion = 2), true, false, 3)
        )
    }

    @Test fun `solo un conflicto real del outbox bloquea la hidratacion remota`() {
        assertEquals(
            JourneyRemoteHydrationDecision.VERSION_CONFLICT,
            JourneyRemoteHydrationPolicy.decide(
                local(syncStatus = "CONFLICTO", syncVersion = 2),
                hasPendingOutbox = false,
                hasUnresolvedConflict = true,
                remoteVersion = 3
            )
        )
    }

    private fun local(syncStatus:String="ENVIADA",syncVersion:Long=1)=JourneyEntity(
        localId=7,
        remoteId="64b42f4f-f63e-4bc2-9238-8ed34cb1dc9c",
        employeeLocalId=12,
        employeeRemoteId="00c8062c-afdf-473f-a427-7448b8435071",
        deviceId="79bb7460-af14-4c81-af58-cb1170c46b99",
        workDate="2026-07-20",
        status="EN_CURSO",
        syncStatus=syncStatus,
        syncVersion=syncVersion
    )
}
