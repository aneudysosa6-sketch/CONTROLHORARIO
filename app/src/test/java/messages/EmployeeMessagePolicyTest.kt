package com.example.controlhorario.messages

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeMessagePolicyTest {
    @Test
    fun validatesSupportedMessageShapes() {
        assertTrue(EmployeeMessagePolicy.isValid("TEXTO", "Aviso", null, 0))
        assertTrue(EmployeeMessagePolicy.isValid("VOZ_SISTEMA", "Aviso", null, 0))
        assertTrue(EmployeeMessagePolicy.isValid("VOZ_GRABADA", null, "https://staging.invalid/audio", 30))
        assertFalse(EmployeeMessagePolicy.isValid("VOZ_GRABADA", null, "http://insecure/audio", 30))
        assertFalse(EmployeeMessagePolicy.isValid("VOZ_GRABADA", null, "https://staging.invalid/audio", 31))
        assertFalse(EmployeeMessagePolicy.isValid("TEXTO", "", null, 0))
    }

    @Test
    fun acceptsOnlyIdempotentReceiptOutcomes() {
        assertTrue(EmployeeMessagePolicy.isReceiptAccepted("accepted"))
        assertTrue(EmployeeMessagePolicy.isReceiptAccepted("duplicate"))
        assertTrue(EmployeeMessagePolicy.isReceiptAccepted("already_received"))
        assertFalse(EmployeeMessagePolicy.isReceiptAccepted("rejected"))
        assertFalse(EmployeeMessagePolicy.isReceiptAccepted(null))
    }
}