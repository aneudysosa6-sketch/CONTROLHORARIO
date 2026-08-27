package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName="journey_outbox",indices=[Index("journeyLocalId"),Index("idempotencyKey",unique=true),Index(value=["state","nextRetryAt"])])
data class JourneyOutboxEntity(
    @PrimaryKey(autoGenerate=true) val id:Long=0,
    val journeyLocalId:Int,
    val operation:String,
    val idempotencyKey:String,
    val payload:String,
    val attempts:Int=0,
    val nextRetryAt:Long=0,
    val lastError:String="",
    val state:String="PENDIENTE",
    val createdAt:Long=System.currentTimeMillis(),
    val sentAt:Long?=null
)
