package com.example.controlhorario.repository

import com.example.controlhorario.database.AppUserDao
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppUserRepositoryTest {
    private val emailUser = user(id = 1, username = "admin", email = "admin@osinet.com", password = "Secret 1")
    private val usernameUser = user(id = 2, username = "Supervisor", password = "Secret 2")

    @Test fun `correo valido aplica trim y minusculas solo al correo`() = runBlocking {
        val result = repository(emailUser).authenticate("  ADMIN@OSINET.COM  ", "Secret 1")
        assertTrue(result is AppUserRepository.LoginResult.Success)
    }

    @Test fun `username valido conserva identificador y resuelve sin distinguir mayusculas`() = runBlocking {
        val result = repository(usernameUser).authenticate(" supervisor ", "Secret 2")
        assertTrue(result is AppUserRepository.LoginResult.Success)
    }

    @Test fun `correo inexistente se diferencia de credenciales invalidas`() = runBlocking {
        val result = repository().authenticate("missing@osinet.com", "Secret 1")
        assertEquals(
            AppUserRepository.LoginIdentifier.Kind.EMAIL,
            (result as AppUserRepository.LoginResult.IdentifierNotFound).kind,
        )
    }

    @Test fun `username inexistente se diferencia de credenciales invalidas`() = runBlocking {
        val result = repository().authenticate("missing", "Secret 1")
        assertEquals(
            AppUserRepository.LoginIdentifier.Kind.USERNAME,
            (result as AppUserRepository.LoginResult.IdentifierNotFound).kind,
        )
    }

    @Test fun `password incorrecto no se recorta ni normaliza`() = runBlocking {
        val result = repository(emailUser).authenticate("admin@osinet.com", " Secret 1 ")
        assertEquals(AppUserRepository.LoginResult.IncorrectPassword, result)
    }

    private fun repository(vararg users: AppUserEntity) = AppUserRepository(FakeDao(users.toList()))

    private fun user(id: Int, username: String, password: String, email: String = "") = AppUserEntity(
        id = id,
        fullName = username,
        username = username,
        email = email,
        password = password,
        createdAt = "2026-07-13",
    )

    private class FakeDao(private val users: List<AppUserEntity>) : AppUserDao {
        override fun getAllUsers(): Flow<List<AppUserEntity>> = flowOf(users)
        override suspend fun getUserByUsername(username: String) = users.firstOrNull { it.username == username }
        override suspend fun getActiveUserByIdentifier(identifier: String) =
            users.firstOrNull { it.isActive && (it.username.equals(identifier, ignoreCase = true) || it.email.equals(identifier, ignoreCase = true)) }
        override suspend fun getUserById(userId: Int) = users.firstOrNull { it.id == userId }
        override suspend fun login(username: String, password: String) =
            users.firstOrNull { it.isActive && it.username == username && it.password == password }
        override suspend fun saveUser(user: AppUserEntity) = Unit
        override suspend fun updateLastLogin(userId: Int, lastLogin: String) = Unit
        override suspend fun deactivateUser(userId: Int, updatedAt: String) = Unit
    }
}
