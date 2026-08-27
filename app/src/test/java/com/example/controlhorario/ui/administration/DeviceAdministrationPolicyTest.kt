package com.example.controlhorario.ui.administration

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceAdministrationPolicyTest {
    private val catalog = DeviceAdministrationCatalog(
        devices = emptyList(),
        branches = listOf(DeviceAdminBranch("branch-a", "Principal", true)),
        departments = listOf(DeviceAdminDepartment("department-a", "branch-a", "Ventas", true)),
    )

    @Test
    fun `device permissions distinguish read and management access`() {
        assertTrue(DeviceAdministrationPolicy.canView(setOf("dispositivos.ver")))
        assertFalse(DeviceAdministrationPolicy.canManage(setOf("dispositivos.ver")))
        assertTrue(DeviceAdministrationPolicy.canManage(setOf("dispositivos.registrar")))
        assertTrue(DeviceAdministrationPolicy.canManage(setOf("kiosk.face_mode_manage")))
    }

    @Test
    fun `department mode requires at least one authorized department`() {
        val draft = validDraft().copy(usageType = "DEPARTMENTS", departmentIds = emptySet())

        assertEquals(
            "SELECCIONE AL MENOS UN DEPARTAMENTO",
            DeviceAdministrationPolicy.validationMessage(draft, catalog),
        )
    }

    @Test
    fun `general mode clears department selection and validates`() {
        val selected = DeviceAdministrationPolicy.departmentsFor("GENERAL", setOf("department-a"))

        assertTrue(selected.isEmpty())
        assertNull(DeviceAdministrationPolicy.validationMessage(validDraft(), catalog))
    }

    @Test
    fun `departments outside selected branch are rejected`() {
        val draft = validDraft().copy(usageType = "DEPARTMENTS", departmentIds = setOf("department-other"))

        assertEquals(
            "La selección contiene departamentos fuera de la sucursal o del alcance autorizado.",
            DeviceAdministrationPolicy.validationMessage(draft, catalog),
        )
    }

    private fun validDraft() = DeviceEditorDraft(
        deviceId = "device-a",
        name = "Terminal Principal",
        state = "activo",
        voiceEnabled = true,
        branchId = "branch-a",
        usageType = "GENERAL",
        departmentIds = emptySet(),
        reason = "Configuración validada",
    )
}