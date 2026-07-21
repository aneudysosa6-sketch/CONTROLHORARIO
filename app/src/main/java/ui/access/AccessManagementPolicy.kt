package com.example.controlhorario.ui.access

data class AccessPolicyDecision(
    val allowed: Boolean,
    val message: String? = null,
) {
    companion object {
        val Allowed = AccessPolicyDecision(allowed = true)
        fun denied(message: String) = AccessPolicyDecision(allowed = false, message = message)
    }
}

object AccessManagementPolicy {
    fun validateCreate(request: CreateAccessRequest, catalog: AccessCatalog): AccessPolicyDecision =
        validate(
            employeeId = request.employeeId,
            username = request.username,
            password = request.password,
            roleId = request.roleId,
            status = request.status,
            editingProfileId = null,
            catalog = catalog,
        )

    fun validateUpdate(
        request: UpdateAccessRequest,
        catalog: AccessCatalog,
        currentProfileId: String = "",
    ): AccessPolicyDecision {
        val base = validate(
            employeeId = request.employeeId,
            username = request.username,
            password = null,
            roleId = request.roleId,
            status = request.status,
            editingProfileId = request.profileId,
            catalog = catalog,
        )
        if (!base.allowed) return base
        val target = catalog.accesses.firstOrNull { it.id == request.profileId }
            ?: return AccessPolicyDecision.denied("El acceso que intentas editar ya no existe.")
        if (!target.status.equals(request.status, ignoreCase = true)) {
            val statusDecision = canSetStatus(target, request.status, currentProfileId, catalog.accesses)
            if (!statusDecision.allowed) return statusDecision
        }
        val requestedRole = catalog.roles.first { it.id == request.roleId }
        if (
            target.isActive &&
            target.isAdministrator() &&
            !requestedRole.isAdministrator() &&
            catalog.accesses.count { it.isActive && it.isAdministrator() } <= 1
        ) {
            return AccessPolicyDecision.denied("No se puede cambiar el rol del último administrador activo.")
        }
        return AccessPolicyDecision.Allowed
    }

    fun canDelete(
        target: AccessAccount,
        currentProfileId: String,
        accesses: List<AccessAccount>,
    ): AccessPolicyDecision {
        if (target.id == currentProfileId) {
            return AccessPolicyDecision.denied("No puedes eliminar el acceso que estás usando actualmente.")
        }
        if (target.isActive && target.isAdministrator() && accesses.count { it.isActive && it.isAdministrator() } <= 1) {
            return AccessPolicyDecision.denied("No se puede eliminar el último administrador.")
        }
        return AccessPolicyDecision.Allowed
    }

    fun canSetStatus(
        target: AccessAccount,
        status: String,
        currentProfileId: String,
        accesses: List<AccessAccount>,
    ): AccessPolicyDecision {
        if (status !in setOf(ACCESS_STATUS_ACTIVE, ACCESS_STATUS_INACTIVE)) {
            return AccessPolicyDecision.denied("El estado seleccionado no es válido.")
        }
        if (
            status == ACCESS_STATUS_INACTIVE &&
            target.id == currentProfileId
        ) {
            return AccessPolicyDecision.denied("No puedes desactivar el acceso que estás usando actualmente.")
        }
        if (
            status == ACCESS_STATUS_INACTIVE &&
            target.isActive &&
            target.isAdministrator() &&
            accesses.count { it.isActive && it.isAdministrator() } <= 1
        ) {
            return AccessPolicyDecision.denied("No se puede desactivar el último administrador activo.")
        }
        return AccessPolicyDecision.Allowed
    }

    fun validatePassword(password: String): AccessPolicyDecision =
        if (password.length < MINIMUM_PASSWORD_LENGTH) AccessPolicyDecision.denied("La contraseña debe tener al menos 8 caracteres.")
        else AccessPolicyDecision.Allowed

    private fun validate(
        employeeId: String,
        username: String,
        password: String?,
        roleId: String,
        status: String,
        editingProfileId: String?,
        catalog: AccessCatalog,
    ): AccessPolicyDecision {
        if (employeeId.isBlank()) return AccessPolicyDecision.denied("Selecciona un empleado.")
        if (username.isBlank()) return AccessPolicyDecision.denied("El usuario es obligatorio.")
        if (!EMAIL_PATTERN.matches(username.trim())) {
            return AccessPolicyDecision.denied("El usuario debe tener formato de correo electrónico para Supabase Auth.")
        }
        if (password != null && password.length < MINIMUM_PASSWORD_LENGTH) {
            return AccessPolicyDecision.denied("La contraseña debe tener al menos 8 caracteres.")
        }
        if (roleId.isBlank() || catalog.roles.none { it.id == roleId }) {
            return AccessPolicyDecision.denied("Selecciona un rol válido.")
        }
        if (status !in setOf(ACCESS_STATUS_ACTIVE, ACCESS_STATUS_INACTIVE)) {
            return AccessPolicyDecision.denied("Selecciona un estado válido.")
        }
        val employee = catalog.employees.firstOrNull { it.id == employeeId }
            ?: return AccessPolicyDecision.denied("El empleado seleccionado ya no está disponible.")
        val profileAssignedToEmployee = employee.profileId?.takeIf(String::isNotBlank)
        if (profileAssignedToEmployee != null && profileAssignedToEmployee != editingProfileId) {
            return AccessPolicyDecision.denied("Este empleado ya tiene un acceso.")
        }
        if (catalog.accesses.any { it.employeeId == employeeId && it.id != editingProfileId }) {
            return AccessPolicyDecision.denied("Este empleado ya tiene un acceso.")
        }
        if (catalog.accesses.any { it.username.equals(username.trim(), ignoreCase = true) && it.id != editingProfileId }) {
            return AccessPolicyDecision.denied("El nombre de usuario ya está en uso.")
        }
        return AccessPolicyDecision.Allowed
    }

    private fun AccessAccount.isAdministrator(): Boolean =
        roleCode.equals("admin", ignoreCase = true) ||
            roleCode.equals("administrador", ignoreCase = true) ||
            roleName.equals("administrador", ignoreCase = true)

    private fun AccessRole.isAdministrator(): Boolean =
        code.equals("admin", ignoreCase = true) ||
            code.equals("administrador", ignoreCase = true) ||
            name.equals("administrador", ignoreCase = true)

    private const val MINIMUM_PASSWORD_LENGTH = 8
    private val EMAIL_PATTERN = Regex("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")
}
