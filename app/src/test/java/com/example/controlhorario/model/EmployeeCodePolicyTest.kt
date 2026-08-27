package com.example.controlhorario.model

import kotlin.random.Random
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.assertThrows
import org.junit.Test

class EmployeeCodePolicyTest {
    @Test
    fun officialSixDigitCodesAreValid() {
        assertTrue(EmployeeCodePolicy.isCanonical("000001"))
        assertTrue(EmployeeCodePolicy.isCanonical("123456"))
        assertFalse(EmployeeCodePolicy.isCanonical("48575"))
    }

    @Test
    fun historicalFiveDigitInputNormalizesToSix() {
        assertTrue(EmployeeCodePolicy.isValid("48575"))
        assertEquals("048575", EmployeeCodePolicy.normalizeOrNull("48575"))
        assertEquals(listOf("048575", "48575"), EmployeeCodePolicy.lookupCandidates("48575"))
    }

    @Test
    fun invalidLengthsLettersAndZeroAreRejected() {
        assertFalse(EmployeeCodePolicy.isValid("1234"))
        assertFalse(EmployeeCodePolicy.isValid("1234567"))
        assertFalse(EmployeeCodePolicy.isValid("12A456"))
        assertFalse(EmployeeCodePolicy.isValid("000000"))
    }

    @Test
    fun randomAllocationIsCanonicalAndSkipsCollisions() {
        val first = EmployeeCodePolicy.randomAvailable(emptyList(), Random(42))
        val second = EmployeeCodePolicy.randomAvailable(listOf(first), Random(42))
        assertTrue(EmployeeCodePolicy.isCanonical(first))
        assertTrue(EmployeeCodePolicy.isCanonical(second))
        assertNotEquals(first, second)
    }

    @Test
    fun exhaustedRangeIsRejected() {
        val allCodes = (1..EmployeeCodePolicy.MAX_VALUE).map { it.toString().padStart(6, '0') }
        assertThrows(IllegalStateException::class.java) {
            EmployeeCodePolicy.randomAvailable(allCodes, Random(1))
        }
    }

    @Test
    fun inputAndLogsRemainSafe() {
        assertEquals("123456", EmployeeCodePolicy.sanitizeInput("12a34567"))
        assertEquals("123456", EmployeeCodePolicy.append("12345", "6"))
        assertEquals("****75", EmployeeCodePolicy.maskForLog("48575"))
        assertEquals("<invalid>", EmployeeCodePolicy.maskForLog("ABC123"))
    }
}