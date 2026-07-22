package com.example.controlhorario.ui.employees

import com.example.controlhorario.model.Employee
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeEditEngineTest{
 @Test fun `editar Aneudy conserva identidad y huella sin crear otro empleado`(){
  val aneudy=Employee(id=27,remoteId="48ae60ea-68dc-4d65-8d6d-e91fb2f2da77",employeeCode="00027",nombre="Aneudy Sosa Valdez",pin="73915",fingerprintRegistered=true,fingerprintRegisteredAt="2026-07-12",fingerprintRegisteredBy="admin")
  assertEquals(aneudy.remoteId,EmployeeEditEngine.routeKey(aneudy));assertEquals("Aneudy Sosa Valdez",EmployeeEditEngine.fieldsFrom(aneudy).nombre)
  val edited=EmployeeEditEngine.merge(aneudy,EmployeeEditableFields("000027","Aneudy Sosa Valdez","001-0000000-1","8095550101","","Supervisor","Operaciones",2,3,50000.0,1.0),1000)
  assertEquals(27,edited.id);assertEquals(aneudy.remoteId,edited.remoteId);assertEquals("000027",edited.employeeCode);assertEquals("",edited.pin);assertTrue(edited.fingerprintRegistered);assertEquals(aneudy.fingerprintRegisteredAt,edited.fingerprintRegisteredAt);assertEquals(aneudy.fingerprintRegisteredBy,edited.fingerprintRegisteredBy);assertEquals("8095550101",edited.telefono)
 }

 @Test fun `editar normaliza codigo y limpia pin historico`(){
  val employee=Employee(id=8,employeeCode="00008",pin="00008")
  val fields=EmployeeEditEngine.fieldsFrom(employee)
  assertEquals("000008",fields.employeeCode)
  val edited=EmployeeEditEngine.merge(employee,fields,1000)
 assertEquals("000008",edited.employeeCode);assertEquals("",edited.pin)
 }

 @Test fun `cambiar codigo nunca vuelve a escribir el pin obsoleto`() {
  val derived=Employee(id=8,employeeCode="000008",pin="000008")
  val independent=derived.copy(pin="92841")
  val fields=EmployeeEditEngine.fieldsFrom(derived).copy(employeeCode="000009")
  assertEquals("",EmployeeEditEngine.merge(derived,fields,1000).pin)
  assertEquals("",EmployeeEditEngine.merge(independent,fields,1000).pin)
 }
}
