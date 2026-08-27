package com.example.controlhorario.ui.punch

import com.example.controlhorario.model.Employee
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeePunchFaceSyncStateTest {
    private val employee = Employee(id = 4, employeeCode = "000008")

    @Test fun `employee code and employee remain while face sync is running`() {
        val state = EmployeePunchState(code = "054321").faceSyncStarted(employee, "054321")
        assertEquals("054321", state.code)
        assertEquals(4, state.employee?.id)
        assertTrue(state.identifying)
        assertEquals("Sincronizando rostro...", state.message)
    }

    @Test fun `network error preserves employee code and offers retry`() {
        val state = EmployeePunchState(code = "054321", employee = employee, identifying = true)
            .faceSyncFailed(employee, "054321")
        assertEquals("054321", state.code)
        assertEquals(employee, state.employee)
        assertFalse(state.identifying)
        assertTrue(state.canRetryFaceSync)
    }
}
