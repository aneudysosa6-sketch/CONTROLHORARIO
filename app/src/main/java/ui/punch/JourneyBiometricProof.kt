package com.example.controlhorario.ui.punch

import com.example.controlhorario.engine.JourneyAction
import java.time.Instant
import java.util.UUID

/** One-use in-memory authorization issued only after a confirmed facial match. */
data class JourneyBiometricProof(val id:String,val employeeLocalId:Int,val deviceId:String,val action:JourneyAction,val issuedAt:String,val expiresAt:String)

object JourneyBiometricGate {
    private const val TTL_MILLIS=90_000L
    private var grant:PendingGrant?=null
    @Synchronized fun open(employeeLocalId:Int,deviceId:String,now:Long=System.currentTimeMillis()){grant=PendingGrant(UUID.randomUUID().toString(),employeeLocalId,deviceId,now+TTL_MILLIS)}
    @Synchronized fun isAuthorized(employeeLocalId:Int,deviceId:String,now:Long=System.currentTimeMillis()):Boolean{
        val current=grant?:return false
        if(now>current.expiresAt){grant=null;return false}
        return !current.proofPrepared&&current.employeeLocalId==employeeLocalId&&current.deviceId==deviceId
    }
    @Synchronized fun prepareProof(employeeLocalId:Int,deviceId:String,action:JourneyAction,now:Long=System.currentTimeMillis()):JourneyBiometricProof?{
        val current=grant?:return null
        if(now>current.expiresAt||current.proofPrepared||current.employeeLocalId!=employeeLocalId||current.deviceId!=deviceId)return null
        grant=current.copy(proofPrepared=true)
        return JourneyBiometricProof(current.id,employeeLocalId,deviceId,action,Instant.ofEpochMilli(now).toString(),Instant.ofEpochMilli(current.expiresAt).toString())
    }
    /** The grant is invalidated only after the protected journey event has been persisted. */
    @Synchronized fun consumeAfterSuccess(proofId:String):Boolean{
        val current=grant?:return false
        if(current.id!=proofId)return false
        grant=null
        return true
    }
    @Synchronized fun clear(){grant=null}
    private data class PendingGrant(val id:String,val employeeLocalId:Int,val deviceId:String,val expiresAt:Long,val proofPrepared:Boolean=false)
}
