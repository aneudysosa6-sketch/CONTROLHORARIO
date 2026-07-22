package com.example.controlhorario.ui.access

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AccessManagementPolicyTest {
    @Test
    fun `permiso granular de crear puede abrir el modulo sin administrar`() {
        val capabilities = AccessCapabilities.from(setOf("usuarios.create"))

        assertTrue(capabilities.canView)
        assertTrue(capabilities.canCreate)
        assertFalse(capabilities.canEdit)
        assertFalse(capabilities.canManage)
    }

    @Test
    fun `empleado vinculado no puede recibir un segundo acceso`() {
        val catalog = catalog(
            accesses = listOf(account(id = "profile-1", employeeId = "employee-1")),
            employeeProfileId = "profile-1",
        )

        val decision = AccessManagementPolicy.validateCreate(validRequest(), catalog)

        assertFalse(decision.allowed)
        assertTrue(decision.message.orEmpty().contains("ya tiene un acceso"))
    }

    @Test
    fun `usuario actual no puede eliminarse`() {
        val target = account(id = "current", employeeId = "employee-1")

        val decision = AccessManagementPolicy.canDelete(target, "current", listOf(target))

        assertFalse(decision.allowed)
    }

    @Test
    fun `ultimo administrador activo no puede eliminarse ni desactivarse`() {
        val target = account(id = "admin-1", employeeId = "employee-1", roleCode = "admin")

        assertFalse(AccessManagementPolicy.canDelete(target, "other", listOf(target)).allowed)
        assertFalse(
            AccessManagementPolicy.canSetStatus(
                target = target,
                status = ACCESS_STATUS_INACTIVE,
                currentProfileId = "other",
                accesses = listOf(target),
            ).allowed
        )
    }

    @Test
    fun `contrasena requiere al menos ocho caracteres`() {
        assertFalse(AccessManagementPolicy.validatePassword("1234567").allowed)
        assertTrue(AccessManagementPolicy.validatePassword("12345678").allowed)
    }

    @Test
    fun `solicitud valida permite crear acceso`() {
        val decision = AccessManagementPolicy.validateCreate(validRequest(), catalog())

        assertTrue(decision.allowed)
    }

    private fun validRequest() = CreateAccessRequest(
        employeeId = "employee-1",
        username = "persona@empresa.com",
        password = "Segura123",
        roleId = "role-1",
        status = ACCESS_STATUS_ACTIVE,
    )

    private fun catalog(
        accesses: List<AccessAccount> = emptyList(),
        employeeProfileId: String? = null,
    ) = AccessCatalog(
        accesses = accesses,
        employees = listOf(
            AccessEmployee(
                id = "employee-1",
                fullName = "Empleado Uno",
                employeeCode = "000001",
                companyId = "company-1",
                profileId = employeeProfileId,
            )
        ),
        roles = listOf(AccessRole("role-1", "Empleado", "employee", "company-1")),
    )

    private fun account(
        id: String,
        employeeId: String,
        roleCode: String = "employee",
    ) = AccessAccount(
        id = id,
        username = "$id@empresa.com",
        email = "$id@empresa.com",
        employeeId = employeeId,
        employeeName = "Empleado Uno",
        employeeCode = "000001",
        roleId = "role-1",
        roleName = if (roleCode == "admin") "Administrador" else "Empleado",
        roleCode = roleCode,
        status = ACCESS_STATUS_ACTIVE,
        lastSignInAt = null,
    )
}
