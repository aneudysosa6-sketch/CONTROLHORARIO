package com.example.controlhorario.auth

import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AuthRepositoryTest {
    @After fun clearSession() = AuthSessionStore.clear()

    @Test fun `correo valido autentica directo sin consultar Room antes de Supabase`() = runBlocking {
        val resolver = FakeResolver(errorIfResolve = true)
        val gateway = FakeGateway()
        val result = repository(resolver, gateway).login("  ADMIN@OSINET.COM ", "Secret 1")
        assertEquals(LoginMode.EMAIL, result.mode)
        assertEquals("admin@osinet.com", gateway.lastEmail)
        assertEquals(0, resolver.resolveCalls)
        assertEquals(1, gateway.signInCalls)
    }

    @Test fun `username valido resuelve correo y usa el mismo Supabase Auth`() = runBlocking {
        val resolver = FakeResolver(usernameEmail = "supervisor@osinet.com")
        val gateway = FakeGateway(profile = profile(roleCode = "supervisor", permissions = setOf("portal.acceder", "supervisor.dashboard")))
        val result = repository(resolver, gateway).login(" Supervisor ", "Secret 2")
        assertEquals(LoginMode.USERNAME, result.mode)
        assertEquals("supervisor@osinet.com", gateway.lastEmail)
        assertEquals(1, resolver.resolveCalls)
    }

    @Test fun `contrasena incorrecta conserva error exacto de Supabase`() = runBlocking {
        val error = AuthFlowException("supabase_auth", "invalid_credentials", "Invalid login credentials")
        val thrown = runCatching { repository(FakeResolver(), FakeGateway(signInError = error)).login("admin@osinet.com", "bad") }.exceptionOrNull()
        assertEquals("invalid_credentials", (thrown as AuthFlowException).code)
    }

    @Test fun `correo inexistente conserva respuesta real de Auth`() = runBlocking {
        val error = AuthFlowException("supabase_auth", "invalid_credentials", "Email not found or invalid credentials")
        val thrown = runCatching { repository(FakeResolver(), FakeGateway(signInError = error)).login("missing@osinet.com", "bad") }.exceptionOrNull()
        assertEquals("Email not found or invalid credentials", thrown?.message)
    }

    @Test fun `profile inexistente impide crear sesion`() = runBlocking {
        val error = AuthFlowException("profile", "PROFILE_NOT_FOUND", "La cuenta Auth no tiene un profile empresarial.")
        val thrown = runCatching { repository(FakeResolver(), FakeGateway(loadError = error)).login("admin@osinet.com", "Secret 1") }.exceptionOrNull()
        assertEquals("PROFILE_NOT_FOUND", (thrown as AuthFlowException).code)
        assertEquals(null, AuthSessionStore.principal.value)
    }

    @Test fun `rol invalido impide abrir Dashboard`() = runBlocking {
        val error = AuthFlowException("role", "ROLE_NOT_FOUND", "Rol inválido")
        val thrown = runCatching { repository(FakeResolver(), FakeGateway(loadError = error)).login("admin@osinet.com", "Secret 1") }.exceptionOrNull()
        assertEquals("role", (thrown as AuthFlowException).stage)
    }

    @Test fun `login exitoso permite iniciar una sesion nueva sin secretos en diagnostico`() = runBlocking {
        val logger = FakeLogger()
        val result = repository(FakeResolver(), FakeGateway(), logger).login("admin@osinet.com", "NeverLogThis")
        AuthSessionStore.start(result.principal)
        assertEquals("auth-uid", AuthSessionStore.principal.value?.authUid)
        val logs = logger.messages.joinToString(" ")
        assertFalse(logs.contains("NeverLogThis"))
        assertFalse(logs.contains("access-token"))
        assertTrue(logs.contains("supabase_auth_llamado=true"))
    }

    private fun repository(resolver: UsernameResolver, gateway: SupabaseAuthGateway, logger: AuthDiagnosticLogger = FakeLogger()) =
        AuthRepository(resolver, gateway, logger)

    private class FakeResolver(
        private val usernameEmail: String? = "admin@osinet.com",
        private val errorIfResolve: Boolean = false,
    ) : UsernameResolver {
        var resolveCalls = 0
        override suspend fun resolveEmail(username: String): String? {
            resolveCalls++
            if (errorIfResolve) error("Room no debe consultarse antes de autenticar un correo")
            return usernameEmail
        }
        override suspend fun findLocalByEmail(email: String) = AppUserEntity(
            id = 1, fullName = "Local", username = "admin", email = email, password = "legacy", createdAt = "",
        )
    }

    private class FakeGateway(
        private val signInError: AuthFlowException? = null,
        private val loadError: AuthFlowException? = null,
        private val profile: AuthorizedProfile = profile(),
    ) : SupabaseAuthGateway {
        var signInCalls = 0
        var lastEmail = ""
        override suspend fun signInWithPassword(email: String, password: String): SupabaseSession {
            signInCalls++; lastEmail = email; signInError?.let { throw it }
            return SupabaseSession("access-token", "auth-uid", email)
        }
        override suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile {
            loadError?.let { throw it }; return profile.copy(email = session.email)
        }
    }

    private class FakeLogger : AuthDiagnosticLogger {
        val messages = mutableListOf<String>()
        override fun info(message: String) { messages += message }
        override fun error(message: String, throwable: Throwable?) { messages += message }
    }

    companion object {
        private fun profile(roleCode: String = "admin", permissions: Set<String> = setOf("portal.acceder", "portal.ver_dashboard")) = AuthorizedProfile(
            authUid = "auth-uid", email = "admin@osinet.com", companyId = "company-id", roleId = "role-id",
            roleCode = roleCode, roleName = roleCode, fullName = "Administrador", permissionCodes = permissions,
        )
    }
}
