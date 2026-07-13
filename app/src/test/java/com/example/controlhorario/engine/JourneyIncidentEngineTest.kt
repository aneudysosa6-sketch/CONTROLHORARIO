package com.example.controlhorario.engine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
class JourneyIncidentEngineTest{
 @Test fun `0714 no genera tardanza`(){assertNull(JourneyIncidentEngine.evaluateLate("2026-07-12T07:00:00Z","2026-07-12T07:14:00Z"))}
 @Test fun `0715 genera tardanza con minutos exactos`(){val result=JourneyIncidentEngine.evaluateLate("2026-07-12T07:00:00Z","2026-07-12T07:15:00Z");assertEquals("TARDANZA",result?.type);assertEquals(15,result?.minutes)}
 @Test fun `sin horario no inventa incidencia`(){assertNull(JourneyIncidentEngine.evaluateLate(null,"2026-07-12T07:30:00Z"))}
}
