package com.example.controlhorario.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "employees",
    indices = [Index(value = ["employeeCode"], unique = true),Index(value=["remoteId"],unique=true)]
)
data class Employee(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeCode: String = "",
    val nombre: String = "",
    val cedula: String = "",
    val telefono: String = "",
    val email: String = "",
    val profilePhotoUri: String = "",
    val cargo: String = "",
    val departamento: String = "",
    val branchId: Int = 0,
    val departmentId: Int = 0,
    val sueldo: Double = 0.0,
    val lunchHours: Double = 0.0,
    /**
     * Obsolete employee credential retained only so Room can open databases created before v38.
     * Employee identification and synchronization must use [employeeCode]; new values stay empty.
     * Administrator/supervisor passwords are stored independently in app_users.
     */
    @Deprecated("El PIN de empleado fue retirado; usa employeeCode.")
    val pin: String = "",
    val fingerprintRegistered: Boolean = false,
    val fingerprintRegisteredAt: String = "",
    val fingerprintRegisteredBy: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val isActive: Boolean = true,
    val remoteId: String? = null,
    val remoteCompanyId: String? = null,
    val remoteBranchId: String? = null,
    val remoteBranchName: String = "",
    val remoteDepartmentId: String? = null,
    val remoteDepartmentName: String = "",
    val remotePositionId: String? = null,
    val remotePositionName: String = "",
    val remoteSupervisorId: String? = null,
    val remoteSupervisorName: String = "",
    val employmentStatus: String = "activo",
    val jornadaEnabled: Boolean = true,
    val remoteScheduleStart: String? = null,
    val remoteScheduleEnd: String? = null,
    val remoteLunchStart: String? = null,
    val remoteLunchDurationMinutes: Int? = null,
    val remoteWorkDays: String? = null,
    val remoteToleranceMinutes: Int? = null,
    val startDate: String? = null,
    val payType: String? = null,
    val remoteUpdatedAt: String? = null,
    val lastSyncedAt: Long? = null,
    val syncStatus: String = "PENDING",
    val lastSyncError: String? = null
)
