package com.example.controlhorario.auth

data class SupabaseSession(
    val accessToken: String,
    val refreshToken: String,
    val accessTokenExpiresAt: Long,
    val authUid: String = "",
    val email: String = "",
) {
    fun isExpired(graceMillis: Long = 60_000L): Boolean =
        accessTokenExpiresAt > 0L && System.currentTimeMillis() >= (accessTokenExpiresAt - graceMillis)
}

data class AuthorizedProfile(
    val authUid: String,
    val profileId: String,
    val employeeId: String?,
    val email: String,
    val companyId: String,
    val roleId: String,
    val roleCodeOriginal: String,
    val roleCode: String,
    val roleName: String,
    val fullName: String,
    val active: Boolean,
    val permissionCodes: Set<String>,
    val primaryDepartmentId: String?,
    val additionalDepartmentIds: Set<String>,
    val branchIds: Set<String>,
    val authorizationVersion: String,
)

data class AuthenticatedPrincipal(
    val authUid: String,
    val profileId: String,
    val employeeId: String?,
    val email: String,
    val companyId: String,
    val roleId: String,
    val roleCodeOriginal: String,
    val roleCode: String,
    val roleName: String,
    val fullName: String,
    val active: Boolean,
    val permissionCodes: Set<String>,
    val primaryDepartmentId: String?,
    val additionalDepartmentIds: Set<String>,
    val branchIds: Set<String>,
    val authorizationVersion: String,
    val accessToken: String,
    val refreshToken: String,
    val accessTokenExpiresAt: Long,
)

class AuthFlowException(
    val stage: String,
    val code: String? = null,
    override val message: String,
    val details: String? = null,
    val hint: String? = null,
    cause: Throwable? = null,
) : Exception(message, cause) {
    fun visibleMessage(): String = listOfNotNull(
        code?.takeIf(String::isNotBlank)?.let { "Código $it" },
        message,
        details?.takeIf(String::isNotBlank)?.let { "Details: $it" },
        hint?.takeIf(String::isNotBlank)?.let { "Hint: $it" },
    ).joinToString(" · ")
}

enum class LoginMode { EMAIL, USERNAME }

data class ResolvedLogin(val mode: LoginMode, val original: String, val email: String)
