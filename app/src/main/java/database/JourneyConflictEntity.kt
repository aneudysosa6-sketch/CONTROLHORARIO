package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName="journey_conflicts",indices=[Index("journeyLocalId"),Index("resolutionState")])
data class JourneyConflictEntity(
    @PrimaryKey(autoGenerate=true) val id:Long=0,
    val journeyLocalId:Int,
    val idempotencyKey:String,
    val localSnapshot:String,
    val remoteSnapshot:String,
    val reason:String,
    val resolutionState:String="PENDIENTE",
    val createdAt:Long=System.currentTimeMillis(),
    val resolvedAt:Long?=null
)
