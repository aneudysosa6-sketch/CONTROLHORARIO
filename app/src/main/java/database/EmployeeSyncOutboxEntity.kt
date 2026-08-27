package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName="employee_sync_outbox",indices=[Index("employeeLocalId"),Index(value=["status","nextRetryAt"]),Index("idempotencyKey",unique=true)])
data class EmployeeSyncOutboxEntity(
 @PrimaryKey(autoGenerate=true) val id:Long=0,val employeeLocalId:Int,val operation:String,val payloadJson:String,val idempotencyKey:String,
 val status:String="PENDING",val retryCount:Int=0,val lastError:String?=null,val nextRetryAt:Long=0,val createdAt:Long=System.currentTimeMillis(),val updatedAt:Long=System.currentTimeMillis()
)
