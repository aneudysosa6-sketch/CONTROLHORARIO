package com.example.controlhorario.auth

import android.util.Log
import com.example.controlhorario.database.AppUserDao
import com.example.controlhorario.database.AppUserEntity

interface AuthDiagnosticLogger {
    fun info(message: String)
    fun error(message: String, throwable: Throwable? = null)
}

object LogcatAuthDiagnosticLogger : AuthDiagnosticLogger {
    override fun info(message: String) {
        Log.i("AndroidAuth", message)
    }

    override fun error(message: String, throwable: Throwable?) {
        Log.e("AndroidAuth", message, throwable)
    }
}

interface UsernameResolver {
    suspend fun resolveEmail(username: String): String?
    suspend fun findLocalByEmail(email: String): AppUserEntity?
}

class RoomUsernameResolver(private val dao: AppUserDao) : UsernameResolver {
    override suspend fun resolveEmail(username: String): String? =
        dao.getActiveUserByIdentifier(username.trim())
            ?.email
            ?.trim()
            ?.lowercase()
            ?.takeIf { '@' in it }

    override suspend fun findLocalByEmail(email: String): AppUserEntity? =
        dao.getActiveUserByIdentifier(email)
}

data class AuthenticatedLogin(
    val user: AppUserEntity,
    val principal: AuthenticatedPrincipal,
    val mode: LoginMode,
)

class AuthRepository(
    private val usernameResolver: UsernameResolver,
    private val gateway: SupabaseAuthGateway,
    private val logger: AuthDiagnosticLogger = LogcatAuthDiagnosticLogger,
) {
    suspend fun login(rawIdentifier: String, password: String): AuthenticatedLogin {
        val identifier = rawIdentifier.trim()
        if (identifier.isBlank()) {
            throw AuthFlowException(
                "identifier",
                code = "IDENTIFIER_REQUIRED",
                message = "Escribe tu correo o nombre de usuario.",
            )
        }
        val mode = if ('@' in identifier) LoginMode.EMAIL else LoginMode.USERNAME
        val email = if (mode == LoginMode.EMAIL) {
            identifier.lowercase()
        } else {
            usernameResolver.resolveEmail(identifier)
                ?: throw AuthFlowException(
                    "username_resolution",
                    code = "USERNAME_NOT_FOUND",
                    message = "El nombre de usuario no existe o no tiene correo Auth vinculado.",
                )
        }
        logger.info("modo=${mode.name}; supabase_auth_llamado=true")
        val session = gateway.signInWithPassword(email, password)
        val authorization = gateway.loadAuthorization(session)
        return buildLogin(session, authorization, mode)
    }

    suspend fun restore(rawSession: SupabaseSession): AuthenticatedLogin {
        val activeSession = if (rawSession.isExpired()) {
            logger.info("auth_session=refresh_inicio; reason=expired")
            gateway.refreshSession(rawSession.refreshToken, rawSession.email)
        } else {
            rawSession
        }
        val authorization = gateway.loadAuthorization(activeSession)
        logger.info(
            "authorization_source=REMOTE; auth_uid=${authorization.authUid}; " +
                "role_code=${authorization.roleCode}; " +
                "permission_count=${authorization.permissionCodes.size}",
        )
        return buildLogin(activeSession, authorization, LoginMode.EMAIL)
    }

    private suspend fun buildLogin(
        session: SupabaseSession,
        authorization: AuthorizedProfile,
        mode: LoginMode,
    ): AuthenticatedLogin {
        if (!authorization.active) {
            throw AuthFlowException(
                "authorization",
                code = "PROFILE_INACTIVE",
                message = "La cuenta esta inactiva.",
            )
        }
        if (authorization.roleCode.isBlank()) {
            throw AuthFlowException(
                "authorization",
                code = "ROLE_CODE_MISSING",
                message = "El perfil no tiene un codigo de rol valido.",
            )
        }
        val local = usernameResolver.findLocalByEmail(authorization.email)
        val user = buildCompatibilityUser(local, authorization)
        val principal = AuthenticatedPrincipal(
            authUid = authorization.authUid,
            profileId = authorization.profileId,
            employeeId = authorization.employeeId,
            email = authorization.email,
            companyId = authorization.companyId,
            roleId = authorization.roleId,
            roleCodeOriginal = authorization.roleCodeOriginal,
            roleCode = authorization.roleCode,
            roleName = authorization.roleName,
            fullName = authorization.fullName,
            active = authorization.active,
            permissionCodes = authorization.permissionCodes,
            primaryDepartmentId = authorization.primaryDepartmentId,
            additionalDepartmentIds = authorization.additionalDepartmentIds,
            branchIds = authorization.branchIds,
            authorizationVersion = authorization.authorizationVersion,
            accessToken = session.accessToken,
            refreshToken = session.refreshToken,
            accessTokenExpiresAt = session.accessTokenExpiresAt,
        )
        return AuthenticatedLogin(user, principal, mode)
    }

    private fun buildCompatibilityUser(
        local: AppUserEntity?,
        authorization: AuthorizedProfile,
    ): AppUserEntity = AppUserEntity(
        id = local?.id
            ?: ((authorization.authUid.hashCode() and Int.MAX_VALUE).takeIf { it != 0 } ?: 1),
        fullName = authorization.fullName,
        username = local?.username ?: authorization.email,
        email = authorization.email,
        role = authorization.roleCode,
        employeeId = local?.employeeId ?: 0,
        branchId = local?.branchId ?: 0,
        departmentId = local?.departmentId ?: 0,
        createdAt = local?.createdAt.orEmpty(),
        updatedAt = local?.updatedAt.orEmpty(),
        lastLoginAt = System.currentTimeMillis().toString(),
    )
}

object AndroidAuthRepositoryFactory {
    fun create(dao: AppUserDao): AuthRepository = AuthRepository(
        usernameResolver = RoomUsernameResolver(dao),
        gateway = SupabaseAuthApi(),
    )
}
