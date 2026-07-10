package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface AppUserDao {

    @Query("""
        SELECT *
        FROM app_users
        WHERE isActive = 1
        ORDER BY fullName
    """)
    fun getAllUsers(): Flow<List<AppUserEntity>>

    @Query("""
        SELECT *
        FROM app_users
        WHERE username = :username
        LIMIT 1
    """)
    suspend fun getUserByUsername(
        username: String
    ): AppUserEntity?

    @Query("""
        SELECT *
        FROM app_users
        WHERE id = :userId
        LIMIT 1
    """)
    suspend fun getUserById(
        userId: Int
    ): AppUserEntity?

    @Query("""
        SELECT *
        FROM app_users
        WHERE username = :username
        AND password = :password
        AND isActive = 1
        LIMIT 1
    """)
    suspend fun login(
        username: String,
        password: String
    ): AppUserEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveUser(
        user: AppUserEntity
    )

    @Query("""
        UPDATE app_users
        SET
            lastLoginAt = :lastLogin
        WHERE id = :userId
    """)
    suspend fun updateLastLogin(
        userId: Int,
        lastLogin: String
    )

    @Query("""
        UPDATE app_users
        SET
            isActive = 0,
            updatedAt = :updatedAt
        WHERE id = :userId
    """)
    suspend fun deactivateUser(
        userId: Int,
        updatedAt: String
    )
}