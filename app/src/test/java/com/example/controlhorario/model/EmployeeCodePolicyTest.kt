package com.example.controlhorario.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeCodePolicyTest{
 @Test fun `cuatro digitos es invalido`(){assertFalse(EmployeeCodePolicy.isValid("1234"))}
 @Test fun `cinco digitos es valido`(){assertTrue(EmployeeCodePolicy.isValid("12345"))}
 @Test fun `sexto digito y caracteres no numericos no pueden escribirse`(){assertEquals("12345",EmployeeCodePolicy.sanitizeInput("12a3456"));assertEquals("12345",EmployeeCodePolicy.append("12345","6"));assertEquals("1234",EmployeeCodePolicy.append("1234","x"))}
}
