package com.example.controlhorario.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "employees",
    indices = [Index(value = ["employeeCode"], unique = true)]
)
data class Employee(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeCode: String = "",
    val nombre: String = "",
    val cedula: String = "",
    val telefono: String = "",
    val profilePhotoUri: String = "",
    val cargo: String = "",
    val departamento: String = "",
    val branchId: Int = 0,
    val departmentId: Int = 0,
    val sueldo: Double = 0.0,
    val lunchHours: Double = 0.0,
    val pin: String = employeeCode,
    val fingerprintRegistered: Boolean = false,
    val fingerprintRegisteredAt: String = "",
    val fingerprintRegisteredBy: String = "",
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val isActive: Boolean = true
)
