package com.example.controlhorario.repository

import com.example.controlhorario.database.AppUserDao
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.flow.Flow

class AppUserRepository(
    private val dao: AppUserDao
) {
    sealed interface LoginResult {
        data class Success(val user: AppUserEntity) : LoginResult
        data class IdentifierNotFound(val kind: LoginIdentifier.Kind) : LoginResult
        data object IncorrectPassword : LoginResult
    }

    data class LoginIdentifier(val value: String, val kind: Kind) {
        enum class Kind { EMAIL, USERNAME }

        companion object {
            fun from(raw: String): LoginIdentifier {
                val trimmed = raw.trim()
                return if ('@' in trimmed) {
                    LoginIdentifier(trimmed.lowercase(), Kind.EMAIL)
                } else {
                    LoginIdentifier(trimmed, Kind.USERNAME)
                }
            }
        }
    }
    fun getAllUsers(): Flow<List<AppUserEntity>> {
        return dao.getAllUsers()
    }

    suspend fun getUserByUsername(username: String): AppUserEntity? {
        return dao.getUserByUsername(username.trim())
    }

    suspend fun getUserById(userId: Int): AppUserEntity? {
        return dao.getUserById(userId)
    }

    suspend fun login(
        username: String,
        password: String
    ): AppUserEntity? {
        return dao.login(
            username = username.trim(),
            password = password.trim()
        )
    }

    /**
     * El identificador se normaliza antes de consultar. La contraseña se compara
     * exactamente como fue escrita: nunca se recorta, normaliza, registra o persiste
     * como parte de la sesión.
     */
    suspend fun authenticate(identifier: String, password: String): LoginResult {
        val normalized = LoginIdentifier.from(identifier)
        val user = dao.getActiveUserByIdentifier(normalized.value)
            ?: return LoginResult.IdentifierNotFound(normalized.kind)
        return if (user.password == password) LoginResult.Success(user)
        else LoginResult.IncorrectPassword
    }

    suspend fun saveUser(user: AppUserEntity) {
        dao.saveUser(user)
    }

    suspend fun updateLastLogin(
        userId: Int,
        lastLogin: String
    ) {
        dao.updateLastLogin(
            userId = userId,
            lastLogin = lastLogin
        )
    }

    suspend fun deactivateUser(
        userId: Int,
        updatedAt: String
    ) {
        dao.deactivateUser(
            userId = userId,
            updatedAt = updatedAt
        )
    }
}
