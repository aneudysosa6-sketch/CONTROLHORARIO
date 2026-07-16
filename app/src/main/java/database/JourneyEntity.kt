package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "journeys", indices = [Index(value=["employeeLocalId","workDate"],unique=true),Index("remoteId",unique=true),Index("syncStatus")])
data class JourneyEntity(
    @PrimaryKey(autoGenerate=true) val localId:Int=0,
    val remoteId:String?=null,
    val employeeLocalId:Int,
    val employeeRemoteId:String,
    val deviceId:String,
    val startBranchId:String?=null,
    val endBranchId:String?=null,
    val workDate:String,
    val status:String="SIN_INICIAR",
    val startedAt:String?=null,
    val pauseStartedAt:String?=null,
    val pauseEndedAt:String?=null,
    val finishedAt:String?=null,
    val workedMinutes:Int=0,
    val breakMinutes:Int=0,
    val syncStatus:String="PENDIENTE",
    val syncVersion:Long=0,
    val lastSyncedAt:Long?=null,
    val createdOffline:Boolean=true,
    val updatedAt:Long=System.currentTimeMillis(),
    val pendingReview:Boolean=false,
    val severity:String="NINGUNA",
    val jornadaEnabledSnapshot:Boolean=true
)
