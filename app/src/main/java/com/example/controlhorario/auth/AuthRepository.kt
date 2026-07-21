package com.example.controlhorario.auth

import android.util.Log
import com.example.controlhorario.database.AppUserDao
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.ui.login.PermissionCatalog

interface AuthDiagnosticLogger {
    fun info(message: String)
    fun error(message: String, throwable: Throwable? = null)
}

object LogcatAuthDiagnosticLogger : AuthDiagnosticLogger {
    override fun info(message: String) { Log.i("AndroidAuth", message) }
    override fun error(message: String, throwable: Throwable?) { Log.e("AndroidAuth", message, throwable) }
}

interface UsernameResolver {
    suspend fun resolveEmail(username: String): String?
    suspend fun findLocalByEmail(email: String): AppUserEntity?
}

class RoomUsernameResolver(private val dao: AppUserDao) : UsernameResolver {
    override suspend fun resolveEmail(username: String): String? =
        dao.getActiveUserByIdentifier(username.trim())?.email?.trim()?.lowercase()?.takeIf { '@' in it }

    override suspend fun findLocalByEmail(email: String): AppUserEntity? = dao.getActiveUserByIdentifier(email)
}

data class AuthenticatedLogin(val user: AppUserEntity, val principal: AuthenticatedPrincipal, val mode: LoginMode)

class AuthRepository(
    private val usernameResolver: UsernameResolver,
    private val gateway: SupabaseAuthGateway,
    private val logger: AuthDiagnosticLogger = LogcatAuthDiagnosticLogger,
) {
    suspend fun login(rawIdentifier: String, password: String): AuthenticatedLogin {
        val identifier = rawIdentifier.trim()
        if (identifier.isBlank()) throw AuthFlowException("identifier", code = "IDENTIFIER_REQUIRED", message = "Escribe tu correo o nombre de usuario.")
        val mode = if ('@' in identifier) LoginMode.EMAIL else LoginMode.USERNAME
        logger.info("modo=${mode.name}; supabase_auth_preparado=true")
        val email = if (mode == LoginMode.EMAIL) identifier.lowercase() else {
            usernameResolver.resolveEmail(identifier)
                ?: throw AuthFlowException("username_resolution", code = "USERNAME_NOT_FOUND", message = "El nombre de usuario no existe o no tiene correo Auth vinculado.")
        }
        logger.info("modo=${mode.name}; supabase_auth_llamado=true")
        val session = try { gateway.signInWithPassword(email, password) } catch (error: AuthFlowException) {
            logger.error("autenticacion=error; etapa=${error.stage}; codigo=${error.code}; error=${error.message}; details=${error.details}; hint=${error.hint}")
            throw error
        }
        logger.info("autenticacion=correcta; auth_uid=${session.authUid}")
        logger.info("profile_carga=iniciada; auth_uid=${session.authUid}")
        val authorization = try { gateway.loadAuthorization(session) } catch (error: AuthFlowException) {
            logger.error("autorizacion=error; etapa=${error.stage}; codigo=${error.code}; error=${error.message}; details=${error.details}; hint=${error.hint}")
            throw error
        }
        logger.info("profile=cargado; auth_uid=${authorization.authUid}; company_id=${authorization.companyId}")
        logger.info("rol=cargado; role_id=${authorization.roleId}; role_code=${authorization.roleCode}")
        logger.info("permisos_efectivos=${authorization.permissionCodes.sorted().joinToString(",")}")
        val local = usernameResolver.findLocalByEmail(email)
        val localPermissions = mapLocalPermissions(authorization.permissionCodes)
        val user = AppUserEntity(
            id = local?.id ?: ((authorization.authUid.hashCode() and Int.MAX_VALUE).takeIf { it != 0 } ?: 1),
            fullName = authorization.fullName,
            username = local?.username ?: email,
            email = email,
            password = "",
            role = authorization.roleCode.uppercase(),
            permissionsCsv = localPermissions.joinToString(","),
            employeeId = local?.employeeId ?: 0,
            branchId = local?.branchId ?: 0,
            departmentId = local?.departmentId ?: 0,
            createdAt = local?.createdAt.orEmpty(),
            updatedAt = local?.updatedAt.orEmpty(),
            lastLoginAt = System.currentTimeMillis().toString(),
        )
        return AuthenticatedLogin(
            user,
            AuthenticatedPrincipal(authorization.authUid, email, authorization.companyId, authorization.roleId, authorization.roleCode, authorization.fullName, authorization.permissionCodes, session.accessToken),
            mode,
        )
    }

    private fun mapLocalPermissions(codes: Set<String>): Set<String> = buildSet {
        if (codes.any { it == "portal.ver_dashboard" || it == "supervisor.dashboard" }) add(PermissionCatalog.DASHBOARD)
        if (codes.any { it.startsWith("empleados.") }) add(PermissionCatalog.EMPLOYEES)
        if (codes.any { it.startsWith("jornadas.") }) add(PermissionCatalog.ATTENDANCE)
        if (codes.any { it.startsWith("incidencias.") }) add(PermissionCatalog.INCIDENTS)
        if (codes.any { it.startsWith("nomina.") }) add(PermissionCatalog.PAYROLL)
        if (codes.any { it.startsWith("reportes.") }) add(PermissionCatalog.REPORTS)
        if (codes.any { it.startsWith("configuracion.") }) add(PermissionCatalog.SETTINGS)
        if (codes.any { it.startsWith("usuarios.") || it.startsWith("permisos.") || it.startsWith("roles.") }) add(PermissionCatalog.USER_PERMISSIONS)
        if (codes.any { it.startsWith("dispositivos.") }) add(PermissionCatalog.PIN_MODE)
        if (PermissionCatalog.KIOSK_PIN_FALLBACK_MANAGE in codes) add(PermissionCatalog.KIOSK_PIN_FALLBACK_MANAGE)
    }
}
