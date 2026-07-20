package com.example.controlhorario.database

import org.junit.Assert.assertEquals
import org.junit.Test

class JourneyRemoteHydrationPolicyTest {
    @Test fun `estado remoto crea cache cuando no existe jornada local`() {
        assertEquals(
            JourneyRemoteHydrationDecision.INSERT,
            JourneyRemoteHydrationPolicy.decide(local = null, hasPendingOutbox = false, remoteVersion = 3)
        )
    }

    @Test fun `version remota mas nueva actualiza una jornada sincronizada`() {
        assertEquals(
            JourneyRemoteHydrationDecision.UPDATE,
            JourneyRemoteHydrationPolicy.decide(local(syncVersion = 2), hasPendingOutbox = false, remoteVersion = 3)
        )
    }

    @Test fun `misma version conserva cache sin reescribirla`() {
        assertEquals(
            JourneyRemoteHydrationDecision.KEEP_LOCAL,
            JourneyRemoteHydrationPolicy.decide(local(syncVersion = 3), hasPendingOutbox = false, remoteVersion = 3)
        )
    }

    @Test fun `accion local pendiente nunca es sobrescrita aunque remoto sea mas nuevo`() {
        val pending = local(syncStatus = "PENDIENTE", syncVersion = 2)
        assertEquals(
            JourneyRemoteHydrationDecision.BLOCKED_PENDING,
            JourneyRemoteHydrationPolicy.decide(pending, hasPendingOutbox = true, remoteVersion = 9)
        )
    }

    @Test fun `version remota anterior produce conflicto y no overwrite`() {
        assertEquals(
            JourneyRemoteHydrationDecision.VERSION_CONFLICT,
            JourneyRemoteHydrationPolicy.decide(local(syncVersion = 8), hasPendingOutbox = false, remoteVersion = 7)
        )
    }

    @Test fun `conflicto local abierto no se resuelve por hidratacion`() {
        assertEquals(
            JourneyRemoteHydrationDecision.VERSION_CONFLICT,
            JourneyRemoteHydrationPolicy.decide(local(syncStatus = "CONFLICTO", syncVersion = 2), false, 3)
        )
    }

    @Test fun `misma version solo conserva cache cuando snapshots coinciden`() {
        val local=local(syncVersion=3)
        assertEquals(
            true,
            JourneyRemoteStateComparator.matches(local,"EN_CURSO",null,null,null,null,0,0)
        )
        assertEquals(
            false,
            JourneyRemoteStateComparator.matches(local,"EN_PAUSA",null,"2026-07-20T16:00:00Z",null,null,0,0)
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
