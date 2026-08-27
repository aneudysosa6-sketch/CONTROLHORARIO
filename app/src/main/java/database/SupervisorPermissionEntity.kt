package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "supervisor_permissions")
data class SupervisorPermissionEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val supervisorUserId: Int,
    val supervisorName: String,
    val employeeId: Int,
    val employeeName: String,
    val canViewProfile: Boolean = true,
    val canManageAttendance: Boolean = false,
    val canApproveVacations: Boolean = false,
    val canApprovePermissions: Boolean = false,
    val canViewPayroll: Boolean = false,
    val createdAt: String,
    val updatedAt: String = createdAt,
    val isActive: Boolean = true
)
