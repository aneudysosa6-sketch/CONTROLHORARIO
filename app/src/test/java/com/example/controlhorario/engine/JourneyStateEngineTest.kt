package com.example.controlhorario.engine

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JourneyStateEngineTest{
 private val t0="2026-07-12T07:00:00Z";private val t1="2026-07-12T11:00:00Z";private val t2="2026-07-12T12:00:00Z";private val t3="2026-07-12T16:00:00Z"
 @Test fun `todas las transiciones validas y minutos son canonicos`(){val start=JourneyStateEngine.apply(JourneySnapshot(),JourneyAction.INICIAR,t0);assertTrue(start.accepted);assertEquals(JourneyStatus.EN_CURSO,start.snapshot.status);val pause=JourneyStateEngine.apply(start.snapshot,JourneyAction.PAUSAR,t1);assertEquals(240,pause.snapshot.workedMinutes);val resume=JourneyStateEngine.apply(pause.snapshot,JourneyAction.REANUDAR,t2);assertEquals(60,resume.snapshot.breakMinutes);val finish=JourneyStateEngine.apply(resume.snapshot,JourneyAction.FINALIZAR,t3);assertEquals(JourneyStatus.FINALIZADA,finish.snapshot.status);assertEquals(480,finish.snapshot.workedMinutes)}
 @Test fun `finalizar durante pausa suma pausa y no trabajo`(){val start=JourneyStateEngine.apply(JourneySnapshot(),JourneyAction.INICIAR,t0).snapshot;val pause=JourneyStateEngine.apply(start,JourneyAction.PAUSAR,t1).snapshot;val finish=JourneyStateEngine.apply(pause,JourneyAction.FINALIZAR,t2);assertEquals(240,finish.snapshot.workedMinutes);assertEquals(60,finish.snapshot.breakMinutes)}
 @Test fun `cada transicion invalida se rechaza`(){val cases=listOf(JourneySnapshot() to listOf(JourneyAction.PAUSAR,JourneyAction.REANUDAR,JourneyAction.FINALIZAR),JourneySnapshot(status=JourneyStatus.EN_CURSO,startedAt=t0) to listOf(JourneyAction.INICIAR,JourneyAction.REANUDAR),JourneySnapshot(status=JourneyStatus.EN_PAUSA,startedAt=t0,pauseStartedAt=t1) to listOf(JourneyAction.INICIAR,JourneyAction.PAUSAR));cases.forEach{(state,actions)->actions.forEach{assertFalse(JourneyStateEngine.apply(state,it,t2).accepted)}}}
 @Test fun `doble toque no crea segunda transicion`(){val started=JourneyStateEngine.apply(JourneySnapshot(),JourneyAction.INICIAR,t0).snapshot;val second=JourneyStateEngine.apply(started,JourneyAction.INICIAR,t0);assertFalse(second.accepted);assertEquals(AttendanceContract.ERROR_INVALID_TRANSITION,second.errorCode)}
 @Test fun `finalizada es irreversible`(){val final=JourneySnapshot(status=JourneyStatus.FINALIZADA,startedAt=t0,finishedAt=t3);JourneyAction.entries.forEach{val result=JourneyStateEngine.apply(final,it,t3);assertFalse(result.accepted);assertEquals(AttendanceContract.ERROR_ALREADY_FINALIZED,result.errorCode)}}
}
