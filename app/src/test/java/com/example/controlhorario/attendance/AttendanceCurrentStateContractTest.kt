package com.example.controlhorario.attendance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AttendanceCurrentStateContractTest {
    @Test fun `acepta fecha estado version y minutos validos`() {
        assertTrue(AttendanceCurrentStateContract.validWorkDate("2026-07-20"))
        assertTrue(AttendanceCurrentStateContract.validRemote("EN_PAUSA",4,180,30))
        assertTrue(AttendanceCurrentStateContract.validRemoteId("11111111-1111-4111-8111-111111111111"))
    }

    @Test fun `rechaza fecha no canonica`() {
        assertFalse(AttendanceCurrentStateContract.validWorkDate("20-07-2026"))
        assertFalse(AttendanceCurrentStateContract.validWorkDate("2026-7-20"))
        assertFalse(AttendanceCurrentStateContract.validWorkDate("2026-13-40"))
        assertFalse(AttendanceCurrentStateContract.validRemoteId("not-a-uuid"))
    }

    @Test fun `rechaza estado desconocido version o minutos negativos`() {
        assertFalse(AttendanceCurrentStateContract.validRemote("ABIERTA",4,180,30))
        assertFalse(AttendanceCurrentStateContract.validRemote("EN_CURSO",-1,180,30))
        assertFalse(AttendanceCurrentStateContract.validRemote("EN_CURSO",4,-1,30))
        assertFalse(AttendanceCurrentStateContract.validRemote("EN_CURSO",4,180,-1))
    }

    @Test fun `vaciado secuencial usa la ultima version local confirmada`() {
        assertEquals(2L,AttendanceKnownVersionPolicy.select(localSyncVersion=2,payloadKnownVersion=1))
        assertEquals(1L,AttendanceKnownVersionPolicy.select(localSyncVersion=null,payloadKnownVersion=1))
    }
}
