package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName="device_enrollment")
data class DeviceEnrollmentEntity(
    @PrimaryKey val deviceId:String,
    val installationId:String,
    val credentialExpiresAt:String,
    val enrolledAt:Long=System.currentTimeMillis(),
    val lastEmployeeSyncAt:Long?=null
)
