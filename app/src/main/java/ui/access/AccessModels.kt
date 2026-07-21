package com.example.controlhorario.ui.access

data class AccessAccount(
    val id: String,
    val username: String,
    val email: String?,
    val employeeId: String,
    val employeeName: String,
    val employeeCode: String,
    val roleId: String,
    val roleName: String,
    val roleCode: String,
    val status: String,
    val lastSignInAt: String?,
) {
    val isActive: Boolean get() = status.equals(ACCESS_STATUS_ACTIVE, ignoreCase = true)
}

data class AccessEmployee(
    val id: String,
    val fullName: String,
    val employeeCode: String,
    val companyId: String,
    val profileId: String?,
)

data class AccessRole(
    val id: String,
    val name: String,
    val code: String,
    val companyId: String,
)

data class AccessCatalog(
    val accesses: List<AccessAccount>,
    val employees: List<AccessEmployee>,
    val roles: List<AccessRole>,
)

data class AccessCapabilities(
    val canView: Boolean,
    val canCreate: Boolean,
    val canEdit: Boolean,
    val canManage: Boolean,
) {
    companion object {
        fun from(permissionCodes: Set<String>): AccessCapabilities {
            val admin = "usuarios.administrar" in permissionCodes
            val canCreate = admin || "usuarios.create" in permissionCodes
            val canEdit = admin || "usuarios.edit" in permissionCodes
            return AccessCapabilities(
                canView = admin || canCreate || canEdit || "usuarios.view" in permissionCodes,
                canCreate = canCreate,
                canEdit = canEdit,
                canManage = admin,
            )
        }
    }
}

data class CreateAccessRequest(
    val employeeId: String,
    val username: String,
    val password: String,
    val roleId: String,
    val status: String,
)

data class UpdateAccessRequest(
    val profileId: String,
    val employeeId: String,
    val username: String,
    val roleId: String,
    val status: String,
)

const val ACCESS_STATUS_ACTIVE = "active"
const val ACCESS_STATUS_INACTIVE = "inactive"
