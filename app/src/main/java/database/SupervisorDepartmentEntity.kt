package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "supervisor_departments",
    indices = [
        Index(value = ["supervisorId"]),
        Index(value = ["departmentId"]),
        Index(value = ["supervisorId", "departmentId"], unique = true)
    ]
)
data class SupervisorDepartmentEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val supervisorId: Int,
    val departmentId: Int,
    val createdAt: Long = System.currentTimeMillis()
)
