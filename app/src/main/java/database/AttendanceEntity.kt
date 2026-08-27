package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "attendance_records")
data class AttendanceEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val employeeName: String,
    val date: String,
    val time: String,
    val actionType: String,
    val latitude: Double = 0.0,
    val longitude: Double = 0.0,
    val biometricVerified: Boolean = false,
    val deviceName: String = "",
    val notes: String = ""
)