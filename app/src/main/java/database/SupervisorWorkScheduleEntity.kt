package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "supervisor_work_schedules",
    indices = [Index(value = ["employeeId"], unique = true)]
)
data class SupervisorWorkScheduleEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val supervisorId: Int,
    val startTime: String,
    val lunchOutTime: String,
    val lunchInTime: String,
    val endTime: String,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis()
)
