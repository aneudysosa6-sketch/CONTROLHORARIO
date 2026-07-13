package com.example.controlhorario.repository

import com.example.controlhorario.database.AppUserDao
import com.example.controlhorario.database.AppUserEntity
import kotlinx.coroutines.flow.Flow

class AppUserRepository(
    private val dao: AppUserDao
) {
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
