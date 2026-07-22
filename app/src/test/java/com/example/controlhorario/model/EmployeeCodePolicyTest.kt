package com.example.controlhorario.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test

class EmployeeCodePolicyTest {
    @Test fun `official six digit codes are valid`() {
        assertTrue(EmployeeCodePolicy.isCanonical("000001"))
        assertTrue(EmployeeCodePolicy.isCanonical("123456"))
        assertFalse(EmployeeCodePolicy.isCanonical("48575"))
    }

    @Test fun `historical five digit input normalizes to six`() {
        assertTrue(EmployeeCodePolicy.isValid("48575"))
        assertEquals("048575", EmployeeCodePolicy.normalizeOrNull("48575"))
        assertEquals(listOf("048575", "48575"), EmployeeCodePolicy.lookupCandidates("48575"))
    }

    @Test fun `invalid lengths letters and zero are rejected`() {
        assertFalse(EmployeeCodePolicy.isValid("1234"))
        assertFalse(EmployeeCodePolicy.isValid("1234567"))
        assertFalse(EmployeeCodePolicy.isValid("12A456"))
        assertFalse(EmployeeCodePolicy.isValid("000000"))
    }

    @Test fun `input accepts only the first six ascii digits`() {
        assertEquals("123456", EmployeeCodePolicy.sanitizeInput("12a34567"))
        assertEquals("123456", EmployeeCodePolicy.append("12345", "6"))
        assertEquals("12345", EmployeeCodePolicy.append("12345", "x"))
    }

    @Test fun `logs expose only the final two digits`() {
        assertEquals("****75",EmployeeCodePolicy.maskForLog("48575"))
        assertEquals("****01",EmployeeCodePolicy.maskForLog("000001"))
        assertEquals("<invalid>",EmployeeCodePolicy.maskForLog("ABC123"))
    }

    @Test fun `next code is six digit ascending and capped`() {
        assertEquals("000001", EmployeeCodePolicy.nextAfter(null))
        assertEquals("048576", EmployeeCodePolicy.nextAfter("48575"))
        assertEquals("123457", EmployeeCodePolicy.nextAfter("123456"))
        assertEquals(
            "000004",
            EmployeeCodePolicy.nextAvailableAfter("000001", listOf("000002", "00003"))
        )
        assertThrows(IllegalStateException::class.java) {
            EmployeeCodePolicy.nextAfter("999999")
        }
    }

}
