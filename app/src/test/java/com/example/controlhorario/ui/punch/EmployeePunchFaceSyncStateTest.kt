package com.example.controlhorario.ui.punch

import com.example.controlhorario.model.Employee
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeePunchFaceSyncStateTest {
    private val employee = Employee(id = 4, employeeCode = "00008", pin = "54321")

    @Test fun `PIN and employee remain while face sync is running`() {
        val state = EmployeePunchState(code = "54321").faceSyncStarted(employee, "54321")
        assertEquals("54321", state.code)
        assertEquals(4, state.employee?.id)
        assertTrue(state.identifying)
        assertEquals("Sincronizando rostro...", state.message)
    }

    @Test fun `network error preserves PIN and offers retry`() {
        val state = EmployeePunchState(code = "54321", employee = employee, identifying = true)
            .faceSyncFailed(employee, "54321")
        assertEquals("54321", state.code)
        assertEquals(employee, state.employee)
        assertFalse(state.identifying)
        assertTrue(state.canRetryFaceSync)
    }
}
