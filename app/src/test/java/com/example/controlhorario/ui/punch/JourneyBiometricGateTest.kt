package com.example.controlhorario.ui.punch

import com.example.controlhorario.engine.JourneyAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class JourneyBiometricGateTest {
 @Test fun `employee code alone never creates a biometric authorization`(){
  JourneyBiometricGate.clear()
  assertFalse(JourneyBiometricGate.isAuthorized(7,"device-a",1))
  assertNull(JourneyBiometricGate.prepareProof(7,"device-a",JourneyAction.INICIAR,1))
 }
 @Test fun `proof remains active until the saved action consumes it`(){
  JourneyBiometricGate.open(7,"device-a",0)
  assertTrue(JourneyBiometricGate.isAuthorized(7,"device-a",1))
  val proof=JourneyBiometricGate.prepareProof(7,"device-a",JourneyAction.INICIAR,1)
  assertEquals(JourneyAction.INICIAR,proof?.action)
  assertFalse(JourneyBiometricGate.isAuthorized(7,"device-a",2))
  assertNull(JourneyBiometricGate.prepareProof(7,"device-a",JourneyAction.FINALIZAR,2))
  assertTrue(JourneyBiometricGate.consumeAfterSuccess(requireNotNull(proof).id))
  assertFalse(JourneyBiometricGate.isAuthorized(7,"device-a",2))
 }
 @Test fun `proof expires and rejects another device`(){
  JourneyBiometricGate.open(7,"device-a",0)
  assertNull(JourneyBiometricGate.prepareProof(7,"device-b",JourneyAction.INICIAR,1))
  JourneyBiometricGate.open(7,"device-a",0)
  assertNull(JourneyBiometricGate.prepareProof(7,"device-a",JourneyAction.INICIAR,90_001))
 }
}
