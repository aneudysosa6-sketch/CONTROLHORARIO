package com.example.controlhorario.ui.punch

import com.example.controlhorario.engine.JourneyAction
import java.time.Instant
import java.util.UUID

/** One-use in-memory authorization issued only after the existing PIN + 2Connect match. */
data class JourneyBiometricProof(val id:String,val employeeLocalId:Int,val deviceId:String,val action:JourneyAction,val issuedAt:String,val expiresAt:String)

object JourneyBiometricGate {
    private const val TTL_MILLIS=90_000L
    private var grant:PendingGrant?=null
    @Synchronized fun open(employeeLocalId:Int,deviceId:String,now:Long=System.currentTimeMillis()){grant=PendingGrant(UUID.randomUUID().toString(),employeeLocalId,deviceId,now+TTL_MILLIS)}
    @Synchronized fun consume(employeeLocalId:Int,deviceId:String,action:JourneyAction,now:Long=System.currentTimeMillis()):JourneyBiometricProof?{val current=grant?:return null;grant=null;if(current.employeeLocalId!=employeeLocalId||current.deviceId!=deviceId||now>current.expiresAt)return null;return JourneyBiometricProof(current.id,employeeLocalId,deviceId,action,Instant.ofEpochMilli(now).toString(),Instant.ofEpochMilli(current.expiresAt).toString())}
    @Synchronized fun clear(){grant=null}
    private data class PendingGrant(val id:String,val employeeLocalId:Int,val deviceId:String,val expiresAt:Long)
}
