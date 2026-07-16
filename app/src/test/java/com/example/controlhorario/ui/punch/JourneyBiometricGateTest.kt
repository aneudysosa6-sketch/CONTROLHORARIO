package com.example.controlhorario.ui.punch

import com.example.controlhorario.engine.JourneyAction
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class JourneyBiometricGateTest {
 @Test fun `proof is bound to employee device action and single use`(){
  JourneyBiometricGate.open(7,"device-a",0)
  val proof=JourneyBiometricGate.consume(7,"device-a",JourneyAction.INICIAR,1)
  assertEquals(JourneyAction.INICIAR,proof?.action)
  assertNull(JourneyBiometricGate.consume(7,"device-a",JourneyAction.INICIAR,2))
 }
 @Test fun `proof expires and rejects another device`(){
  JourneyBiometricGate.open(7,"device-a",0)
  assertNull(JourneyBiometricGate.consume(7,"device-b",JourneyAction.INICIAR,1))
  JourneyBiometricGate.open(7,"device-a",0)
  assertNull(JourneyBiometricGate.consume(7,"device-a",JourneyAction.INICIAR,90_001))
 }
}
