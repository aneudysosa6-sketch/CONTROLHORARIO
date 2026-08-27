package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "employee_face_biometrics",
    indices = [Index(value = ["employeeId"], unique = true)]
)
data class EmployeeFaceBiometricEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val employeeId: Int,
    val encryptedEmbedding: String,
    val embeddingVersion: Int,
    val modelName: String,
    val embeddingDimension: Int,
    val registeredAt: String,
    val registeredBy: String,
    val updatedAt: String,
    val isActive: Boolean = true
)
