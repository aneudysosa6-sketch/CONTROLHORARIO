package com.example.controlhorario.auth

import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthRepositoryTest {
    @Test
    fun `email login authenticates directly and loads remote authorization`() = runBlocking {
        val resolver = FakeResolver(errorIfResolve = true)
        val gateway = FakeGateway()

        val result = repository(resolver, gateway).login("  ADMIN@OSINET.COM ", "Secret 1")

        assertEquals(LoginMode.EMAIL, result.mode)
        assertEquals("admin@osinet.com", gateway.lastEmail)
        assertEquals(0, resolver.resolveCalls)
        assertEquals(1, gateway.signInCalls)
        assertEquals(1, gateway.authorizationCalls)
    }

    @Test
    fun `username resolves email and uses the same Supabase Auth flow`() = runBlocking {
        val resolver = FakeResolver(usernameEmail = "supervisor@osinet.com")
        val gateway = FakeGateway(profile = profile("SUPERVISOR", setOf("supervisor.dashboard")))

        val result = repository(resolver, gateway).login(" Supervisor ", "Secret 2")

        assertEquals(LoginMode.USERNAME, result.mode)
        assertEquals("supervisor@osinet.com", gateway.lastEmail)
        assertEquals("SUPERVISOR", result.principal.roleCode)
        assertEquals(1, resolver.resolveCalls)
        assertEquals(1, gateway.authorizationCalls)
    }

    @Test
    fun `restoring the same tokens rebuilds principal from current remote role`() = runBlocking {
        val gateway = FakeGateway(profile = profile("SUPERVISOR", setOf("supervisor.dashboard")))
        val repository = repository(FakeResolver(), gateway)
        val persisted = session()

        val supervisor = repository.restore(persisted)
        gateway.profile = profile("EMPLEADO", setOf("empleado.perfil_ver"))
        val employee = repository.restore(persisted)
        gateway.profile = profile("ADMIN", setOf("portal.ver_dashboard"))
        val admin = repository.restore(persisted)

        assertEquals("SUPERVISOR", supervisor.principal.roleCode)
        assertEquals("EMPLEADO", employee.principal.roleCode)
        assertEquals("ADMIN", admin.principal.roleCode)
        assertEquals(setOf("supervisor.dashboard"), supervisor.principal.permissionCodes)
        assertEquals(setOf("empleado.perfil_ver"), employee.principal.permissionCodes)
        assertEquals(setOf("portal.ver_dashboard"), admin.principal.permissionCodes)
        assertEquals(3, gateway.authorizationCalls)
    }

    @Test
    fun `expired token refreshes before loading remote authorization`() = runBlocking {
        val gateway = FakeGateway()
        val expired = session(expiresAt = 1L)

        val result = repository(FakeResolver(), gateway).restore(expired)

        assertEquals(1, gateway.refreshCalls)
        assertEquals(1, gateway.authorizationCalls)
        assertEquals("refreshed-access", result.principal.accessToken)
    }

    @Test
    fun `inactive remote profile cannot create a principal`() = runBlocking {
        val gateway = FakeGateway(profile = profile("SUPERVISOR", emptySet()).copy(active = false))

        val thrown = runCatching {
            repository(FakeResolver(), gateway).restore(session())
        }.exceptionOrNull() as AuthFlowException

        assertEquals("PROFILE_INACTIVE", thrown.code)
    }

    @Test
    fun `diagnostics never contain password or tokens`() = runBlocking {
        val logger = FakeLogger()

        repository(FakeResolver(), FakeGateway(), logger)
            .login("admin@osinet.com", "NeverLogThis")

        val logs = logger.messages.joinToString(" ")
        assertFalse(logs.contains("NeverLogThis"))
        assertFalse(logs.contains("access-token"))
        assertFalse(logs.contains("refresh-token"))
        assertTrue(logs.contains("supabase_auth_llamado=true"))
    }

    private fun repository(
        resolver: UsernameResolver,
        gateway: SupabaseAuthGateway,
        logger: AuthDiagnosticLogger = FakeLogger(),
    ) = AuthRepository(resolver, gateway, logger)

    private class FakeResolver(
        private val usernameEmail: String? = "admin@osinet.com",
        private val errorIfResolve: Boolean = false,
    ) : UsernameResolver {
        var resolveCalls = 0

        override suspend fun resolveEmail(username: String): String? {
            resolveCalls++
            if (errorIfResolve) error("Room must not resolve an email identifier")
            return usernameEmail
        }

        override suspend fun findLocalByEmail(email: String) = AppUserEntity(
            id = 1,
            fullName = "Local",
            username = "admin",
            email = email,
            createdAt = "",
        )
    }

    private class FakeGateway(
        var profile: AuthorizedProfile = profile(),
    ) : SupabaseAuthGateway {
        var signInCalls = 0
        var refreshCalls = 0
        var authorizationCalls = 0
        var lastEmail = ""

        override suspend fun signInWithPassword(email: String, password: String): SupabaseSession {
            signInCalls++
            lastEmail = email
            return session(email = email)
        }

        override suspend fun refreshSession(
            refreshToken: String,
            emailFallback: String,
        ): SupabaseSession {
            refreshCalls++
            return session(accessToken = "refreshed-access", email = emailFallback)
        }

        override suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile {
            authorizationCalls++
            return profile.copy(email = session.email.ifBlank { profile.email })
        }
    }

    private class FakeLogger : AuthDiagnosticLogger {
        val messages = mutableListOf<String>()
        override fun info(message: String) {
            messages += message
        }

        override fun error(message: String, throwable: Throwable?) {
            messages += message
        }
    }

    companion object {
        private fun session(
            accessToken: String = "access-token",
            expiresAt: Long = Long.MAX_VALUE,
            email: String = "admin@osinet.com",
        ) = SupabaseSession(
            accessToken = accessToken,
            refreshToken = "refresh-token",
            accessTokenExpiresAt = expiresAt,
            authUid = "auth-uid",
            email = email,
        )

        private fun profile(
            roleCode: String = "ADMIN",
            permissions: Set<String> = setOf("portal.acceder", "portal.ver_dashboard"),
        ) = AuthorizedProfile(
            authUid = "auth-uid",
            profileId = "profile-id",
            employeeId = null,
            email = "admin@osinet.com",
            companyId = "company-id",
            roleId = "role-id",
            roleCodeOriginal = roleCode.lowercase(),
            roleCode = roleCode,
            roleName = roleCode,
            fullName = "Usuario",
            active = true,
            permissionCodes = permissions,
            primaryDepartmentId = null,
            additionalDepartmentIds = emptySet(),
            branchIds = emptySet(),
            authorizationVersion = "v1",
        )
    }
}
