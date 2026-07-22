package com.example.controlhorario.ui.punch

import android.util.Log
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthRepository
import com.example.controlhorario.auth.AuthenticatedLogin
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.ui.login.PermissionCatalog
import com.example.controlhorario.ui.login.hasPermission
import java.util.Locale
import kotlinx.coroutines.CancellationException

fun interface KioskExitAuthenticator {
    suspend fun authenticate(identifier: String, password: String): AuthenticatedLogin
}

class AuthRepositoryKioskExitAuthenticator(
    private val repository: AuthRepository,
) : KioskExitAuthenticator {
    override suspend fun authenticate(identifier: String, password: String): AuthenticatedLogin =
        repository.login(identifier, password)
}

interface KioskExitRuntime {
    fun setPrincipal(principal: AuthenticatedPrincipal)
    fun loginRemote(user: AppUserEntity)
    suspend fun deactivateAndPersist(): Boolean
    fun isKioskActive(): Boolean
    fun clearSession()
}

interface KioskExitLogger {
    fun log(
        stage: String,
        userId: Int? = null,
        roleCode: String? = null,
        errorCode: String? = null,
    )
}

object LogcatKioskExitLogger : KioskExitLogger {
    override fun log(stage: String, userId: Int?, roleCode: String?, errorCode: String?) {
        val message = buildList {
            add("stage=$stage")
            userId?.let { add("userId=$it") }
            roleCode?.takeIf(String::isNotBlank)?.let { add("roleCode=$it") }
            errorCode?.takeIf(String::isNotBlank)?.let { add("errorCode=$it") }
        }.joinToString("; ")
        if (errorCode == null) Log.i(TAG, message) else Log.e(TAG, message)
    }

    private const val TAG = "KIOSK_EXIT_FLOW"
}

object KioskExitStages {
    const val AUTHENTICATION_STARTED = "authentication_started"
    const val AUTHENTICATION_SUCCESS = "authentication_success"
    const val PRINCIPAL_LOADED = "principal_loaded"
    const val KIOSK_DEACTIVATED = "kiosk_deactivated"
    const val NAVIGATION_HOME = "navigation_home"
    const val ERROR = "error"
}

object KioskExitPermissionPolicy {
    const val PIN_MODE_EXIT = "kiosk.pin_mode_exit"

    fun canExit(login: AuthenticatedLogin): Boolean =
        PIN_MODE_EXIT in login.principal.permissionCodes ||
            login.user.permissionsCsv.hasPermission(PermissionCatalog.EMPLOYEE_MODE)
}

enum class KioskExitFailureCode {
    INVALID_CREDENTIALS,
    INACTIVE_USER,
    PERMISSION_DENIED,
    KIOSK_PERSISTENCE_FAILED,
    AUTHENTICATION_FAILED,
    SESSION_FAILED,
}

sealed interface KioskExitResult {
    data class Success(
        val userId: Int,
        val roleCode: String,
    ) : KioskExitResult

    data class Failure(
        val code: KioskExitFailureCode,
        val message: String,
    ) : KioskExitResult
}

class KioskExitCoordinator(
    private val authenticator: KioskExitAuthenticator,
    private val runtime: KioskExitRuntime,
    private val logger: KioskExitLogger = LogcatKioskExitLogger,
) {
    suspend fun exit(identifier: String, password: String): KioskExitResult {
        safeLog(KioskExitStages.AUTHENTICATION_STARTED)
        val login = try {
            authenticator.authenticate(identifier, password)
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (error: AuthFlowException) {
            return authenticationFailure(error)
        } catch (_: Exception) {
            return failure(
                code = KioskExitFailureCode.AUTHENTICATION_FAILED,
                message = AUTHENTICATION_ERROR_MESSAGE,
            )
        }

        val userId = login.user.id
        val roleCode = login.principal.roleCode
        safeLog(KioskExitStages.AUTHENTICATION_SUCCESS, userId, roleCode)

        if (!login.user.isActive) {
            return failure(
                code = KioskExitFailureCode.INACTIVE_USER,
                message = INACTIVE_USER_MESSAGE,
                userId = userId,
                roleCode = roleCode,
            )
        }
        if (!KioskExitPermissionPolicy.canExit(login)) {
            return failure(
                code = KioskExitFailureCode.PERMISSION_DENIED,
                message = PERMISSION_DENIED_MESSAGE,
                userId = userId,
                roleCode = roleCode,
            )
        }

        var sessionStarted = false
        return try {
            sessionStarted = true
            runtime.setPrincipal(login.principal)
            safeLog(KioskExitStages.PRINCIPAL_LOADED, userId, roleCode)

            runtime.loginRemote(login.user)
            val persisted = runtime.deactivateAndPersist()
            if (!persisted || runtime.isKioskActive()) {
                clearPartialSession()
                failure(
                    code = KioskExitFailureCode.KIOSK_PERSISTENCE_FAILED,
                    message = KIOSK_PERSISTENCE_ERROR_MESSAGE,
                    userId = userId,
                    roleCode = roleCode,
                )
            } else {
                safeLog(KioskExitStages.KIOSK_DEACTIVATED, userId, roleCode)
                KioskExitResult.Success(userId = userId, roleCode = roleCode)
            }
        } catch (cancelled: CancellationException) {
            if (sessionStarted) clearPartialSession()
            throw cancelled
        } catch (_: Exception) {
            if (sessionStarted) clearPartialSession()
            failure(
                code = KioskExitFailureCode.SESSION_FAILED,
                message = SESSION_ERROR_MESSAGE,
                userId = userId,
                roleCode = roleCode,
            )
        }
    }

    private fun authenticationFailure(error: AuthFlowException): KioskExitResult.Failure {
        val normalizedCode = error.code.orEmpty().lowercase(Locale.ROOT)
        return when (normalizedCode) {
            "invalid_credentials", "invalid_login_credentials", "username_not_found" -> failure(
                code = KioskExitFailureCode.INVALID_CREDENTIALS,
                message = INVALID_CREDENTIALS_MESSAGE,
            )
            "profile_inactive", "role_inactive" -> failure(
                code = KioskExitFailureCode.INACTIVE_USER,
                message = INACTIVE_USER_MESSAGE,
            )
            "portal_access_denied" -> failure(
                code = KioskExitFailureCode.PERMISSION_DENIED,
                message = PERMISSION_DENIED_MESSAGE,
            )
            else -> failure(
                code = KioskExitFailureCode.AUTHENTICATION_FAILED,
                message = AUTHENTICATION_ERROR_MESSAGE,
            )
        }
    }

    private fun failure(
        code: KioskExitFailureCode,
        message: String,
        userId: Int? = null,
        roleCode: String? = null,
    ): KioskExitResult.Failure {
        safeLog(KioskExitStages.ERROR, userId, roleCode, code.name)
        return KioskExitResult.Failure(code, message)
    }

    private fun clearPartialSession() {
        runCatching { runtime.clearSession() }
    }

    private fun safeLog(
        stage: String,
        userId: Int? = null,
        roleCode: String? = null,
        errorCode: String? = null,
    ) {
        runCatching { logger.log(stage, userId, roleCode, errorCode) }
    }

    companion object {
        const val INVALID_CREDENTIALS_MESSAGE = "Usuario o contraseña incorrectos"
        const val INACTIVE_USER_MESSAGE = "Usuario inactivo"
        const val PERMISSION_DENIED_MESSAGE = "No tiene permiso para salir del modo empleado"
        const val KIOSK_PERSISTENCE_ERROR_MESSAGE =
            "No se pudo desactivar el modo empleado. Intente nuevamente"
        const val AUTHENTICATION_ERROR_MESSAGE =
            "No se pudo completar la autenticación. Intente nuevamente"
        const val SESSION_ERROR_MESSAGE =
            "No se pudo restaurar la sesión administrativa. Intente nuevamente"
    }
}
