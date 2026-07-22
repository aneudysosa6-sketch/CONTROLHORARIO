package com.example.controlhorario.device

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeUploadAuthorityPolicyTest {
    @Test fun `create accepts and normalizes the authoritative server code`() {
        assertTrue(EmployeeUploadAuthorityPolicy.accepts("CREATE", "048575"))
        assertTrue(EmployeeUploadAuthorityPolicy.accepts("CREATE", "48575"))
        assertEquals(
            "048575",
            EmployeeUploadAuthorityPolicy.authoritativeCode("CREATE", "48575")
        )
        assertFalse(EmployeeUploadAuthorityPolicy.accepts("CREATE", null))
        assertFalse(EmployeeUploadAuthorityPolicy.accepts("CREATE", "ABC123"))
    }

    @Test fun `updates do not require code allocation response`() {
        assertTrue(EmployeeUploadAuthorityPolicy.accepts("UPDATE", null))
        assertEquals(null,EmployeeUploadAuthorityPolicy.authoritativeCode("UPDATE","000001"))
    }
}
