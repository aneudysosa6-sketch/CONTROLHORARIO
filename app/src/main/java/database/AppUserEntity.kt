package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "app_users")
data class AppUserEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val fullName: String,
    val username: String,
    val password: String,
    val role: String = UserRole.ADMINISTRADOR.name,
    val permissionsCsv: String = "",
    val employeeId: Int = 0,
    val branchId: Int = 0,
    val departmentId: Int = 0,
    val isActive: Boolean = true,
    val createdAt: String,
    val updatedAt: String = "",
    val lastLoginAt: String = ""
)