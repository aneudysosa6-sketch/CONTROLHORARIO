package com.example.controlhorario.ui.punch

import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthenticatedLogin
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.LoginMode
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class KioskExitCoordinatorTest {
    @Test
    fun `admin autorizado restaura ambas sesiones antes de persistir salida y navegar`() = runBlocking {
        val runtime = FakeRuntime()
        val logger = FakeLogger()
        val coordinator = coordinator(
            login = login(roleCode = "admin", remotePermissions = setOf(KioskExitPermissionPolicy.FACE_MODE_MANAGE)),
            runtime = runtime,
            logger = logger,
        )

        val result = coordinator.exit("admin@example.com", "NeverLogThis")

        assertEquals(KioskExitResult.Success(userId = 17, roleCode = "admin"), result)
        assertEquals(
            listOf("startSession", "deactivateAndPersist", "isKioskActive"),
            runtime.events,
        )
        assertFalse(runtime.kioskActive)
        assertEquals(
            listOf(
                KioskExitStages.AUTHENTICATION_STARTED,
                KioskExitStages.AUTHENTICATION_SUCCESS,
                KioskExitStages.PRINCIPAL_LOADED,
                KioskExitStages.KIOSK_DEACTIVATED,
            ),
            logger.entries.map { it.stage },
        )
        assertFalse(logger.serialized().contains("admin@example.com"))
        assertFalse(logger.serialized().contains("NeverLogThis"))
        assertFalse(logger.serialized().contains("access-token"))
    }

    @Test
    fun `local metadata cannot replace the required remote permission`() = runBlocking {
        val runtime = FakeRuntime()
        val result = coordinator(
            login = login(
                roleCode = "SUPERVISOR",
                remotePermissions = setOf("portal.acceder", "supervisor.dashboard"),
            ),
            runtime = runtime,
        ).exit("supervisor", "secret")

        assertEquals(KioskExitFailureCode.PERMISSION_DENIED, (result as KioskExitResult.Failure).code)
        assertTrue(runtime.kioskActive)
        assertTrue(runtime.events.isEmpty())
    }

    @Test
    fun `contrasena incorrecta conserva kiosco y no crea sesion parcial`() = runBlocking {
        val runtime = FakeRuntime()
        val logger = FakeLogger()
        val coordinator = KioskExitCoordinator(
            authenticator = KioskExitAuthenticator {
                _, _ -> throw AuthFlowException("supabase_auth", "invalid_credentials", "Invalid login credentials")
            },
            runtime = runtime,
            logger = logger,
        )

        val result = coordinator.exit("admin", "bad")

        assertEquals(
            KioskExitResult.Failure(
                KioskExitFailureCode.INVALID_CREDENTIALS,
                "Usuario o contraseña incorrectos",
            ),
            result,
        )
        assertTrue(runtime.kioskActive)
        assertTrue(runtime.events.isEmpty())
        assertEquals(
            listOf(KioskExitStages.AUTHENTICATION_STARTED, KioskExitStages.ERROR),
            logger.entries.map { it.stage },
        )
    }

    @Test
    fun `usuario inactivo es rechazado antes de tocar runtime`() = runBlocking {
        val runtime = FakeRuntime()
        val result = coordinator(
            login = login(
                roleCode = "admin",
                remotePermissions = setOf(KioskExitPermissionPolicy.FACE_MODE_MANAGE),
                active = false,
            ),
            runtime = runtime,
        ).exit("admin", "secret")

        assertEquals(KioskExitFailureCode.INACTIVE_USER, (result as KioskExitResult.Failure).code)
        assertTrue(runtime.kioskActive)
        assertTrue(runtime.events.isEmpty())
    }

    @Test
    fun `usuario sin permiso es rechazado sin crear sesion ni desactivar kiosco`() = runBlocking {
        val runtime = FakeRuntime()
        val result = coordinator(
            login = login(roleCode = "admin", remotePermissions = setOf("portal.acceder")),
            runtime = runtime,
        ).exit("admin", "secret")

        assertEquals(KioskExitFailureCode.PERMISSION_DENIED, (result as KioskExitResult.Failure).code)
        assertTrue(runtime.kioskActive)
        assertTrue(runtime.events.isEmpty())
    }

    @Test
    fun `fallo al persistir kiosco revierte la sesion y no ordena navegar`() = runBlocking {
        val runtime = FakeRuntime(persistResult = false)
        val logger = FakeLogger()
        val result = coordinator(
            login = login(roleCode = "admin", remotePermissions = setOf(KioskExitPermissionPolicy.FACE_MODE_MANAGE)),
            runtime = runtime,
            logger = logger,
        ).exit("admin", "secret")

        assertEquals(KioskExitFailureCode.KIOSK_PERSISTENCE_FAILED, (result as KioskExitResult.Failure).code)
        assertEquals(
            listOf("startSession", "deactivateAndPersist", "clearSession"),
            runtime.events,
        )
        assertTrue(runtime.kioskActive)
        assertFalse(logger.entries.any { it.stage == KioskExitStages.NAVIGATION_HOME })
    }

    @Test
    fun `kiosco que sigue activo tras persistir revierte la sesion`() = runBlocking {
        val runtime = FakeRuntime(persistResult = true, remainActiveAfterPersist = true)
        val result = coordinator(
            login = login(roleCode = "admin", remotePermissions = setOf(KioskExitPermissionPolicy.FACE_MODE_MANAGE)),
            runtime = runtime,
        ).exit("admin", "secret")

        assertEquals(KioskExitFailureCode.KIOSK_PERSISTENCE_FAILED, (result as KioskExitResult.Failure).code)
        assertEquals(
            listOf(
                "startSession",
                "deactivateAndPersist",
                "isKioskActive",
                "clearSession",
            ),
            runtime.events,
        )
    }

    private fun coordinator(
        login: AuthenticatedLogin,
        runtime: FakeRuntime,
        logger: FakeLogger = FakeLogger(),
    ) = KioskExitCoordinator(
        authenticator = KioskExitAuthenticator { _, _ -> login },
        runtime = runtime,
        logger = logger,
    )

    private fun login(
        roleCode: String,
        remotePermissions: Set<String>,
        active: Boolean = true,
    ): AuthenticatedLogin {
        val user = AppUserEntity(
            id = 17,
            fullName = "Usuario autorizado",
            username = "local-user",
            email = "user@example.com",
            role = roleCode.uppercase(),
            isActive = active,
            createdAt = "",
        )
        val principal = AuthenticatedPrincipal(
            authUid = "auth-uid",
            profileId = "profile-id",
            employeeId = null,
            email = "user@example.com",
            companyId = "company-id",
            roleId = "role-id",
            roleCodeOriginal = roleCode.lowercase(),
            roleCode = roleCode,
            roleName = roleCode,
            fullName = user.fullName,
            active = active,
            permissionCodes = remotePermissions,
            primaryDepartmentId = null,
            additionalDepartmentIds = emptySet(),
            branchIds = emptySet(),
            authorizationVersion = "v1",
            accessToken = "access-token",
            refreshToken = "refresh-token",
            accessTokenExpiresAt = Long.MAX_VALUE,
        )
        return AuthenticatedLogin(user, principal, LoginMode.EMAIL)
    }

    private class FakeRuntime(
        private val persistResult: Boolean = true,
        private val remainActiveAfterPersist: Boolean = false,
    ) : KioskExitRuntime {
        val events = mutableListOf<String>()
        var kioskActive = true

        override fun startSession(login: AuthenticatedLogin) {
            events += "startSession"
        }

        override suspend fun deactivateAndPersist(): Boolean {
            events += "deactivateAndPersist"
            if (persistResult && !remainActiveAfterPersist) kioskActive = false
            return persistResult
        }

        override fun isKioskActive(): Boolean {
            events += "isKioskActive"
            return kioskActive
        }

        override fun clearSession() {
            events += "clearSession"
        }
    }

    private data class LogEntry(
        val stage: String,
        val userId: Int?,
        val roleCode: String?,
        val errorCode: String?,
    )

    private class FakeLogger : KioskExitLogger {
        val entries = mutableListOf<LogEntry>()

        override fun log(stage: String, userId: Int?, roleCode: String?, errorCode: String?) {
            entries += LogEntry(stage, userId, roleCode, errorCode)
        }

        fun serialized(): String = entries.joinToString("|")
    }
}
