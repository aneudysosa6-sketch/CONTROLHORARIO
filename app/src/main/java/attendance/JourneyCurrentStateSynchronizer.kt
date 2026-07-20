package com.example.controlhorario.attendance

import android.util.Log
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.database.EmployeeDao
import com.example.controlhorario.database.JourneyDao
import com.example.controlhorario.database.JourneyRemoteHydrationDecision
import com.example.controlhorario.repository.JourneyCurrentStateOutcome
import com.example.controlhorario.repository.JourneyCurrentStateRefreshResult
import com.example.controlhorario.repository.JourneyCurrentStateSyncException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.time.Instant
import java.time.ZoneId

data class AttendanceDeviceSession(val deviceId:String,val credential:String)

object AttendanceSyncExecutionGate {
    val mutex = Mutex()
}

internal object JourneyCurrentStateFallbackPolicy {
    fun outcome(
        hasPendingOutbox:Boolean,
        cacheSyncStatus:String?,
        cacheWorkDate:String?,
        expectedWorkDate:String
    ):JourneyCurrentStateOutcome?=when{
        hasPendingOutbox->JourneyCurrentStateOutcome.LOCAL_PENDING
        cacheSyncStatus=="ENVIADA"&&cacheWorkDate==expectedWorkDate->JourneyCurrentStateOutcome.LOCAL_CACHE
        else->null
    }
}

class JourneyCurrentStateSynchronizer(
    private val journeyDao:JourneyDao,
    private val employeeDao:EmployeeDao,
    private val gateway:AttendanceSyncGateway,
    private val sessionProvider:()->AttendanceDeviceSession?,
    private val ioDispatcher:CoroutineDispatcher=Dispatchers.IO
) {
    suspend fun refresh(employeeLocalId:Int,requestedAt:String):JourneyCurrentStateRefreshResult =
        withContext(ioDispatcher) {
            AttendanceSyncExecutionGate.mutex.withLock {
                refreshLocked(employeeLocalId,requestedAt)
            }
        }

    private suspend fun refreshLocked(employeeLocalId:Int,requestedAt:String):JourneyCurrentStateRefreshResult {
        validateRequestedAt(requestedAt)
        val employee=employeeDao.findByLocalId(employeeLocalId)
            ?:throw JourneyCurrentStateSyncException("EMPLOYEE_NOT_FOUND",JourneyCurrentStateOutcome.CONFLICT)
        val employeeRemoteId=employee.remoteId?.takeIf(String::isNotBlank)
            ?:throw JourneyCurrentStateSyncException("EMPLOYEE_REMOTE_ID_MISSING",JourneyCurrentStateOutcome.CONFLICT)
        val session=sessionProvider()?:return cachedFallbackOrThrow(
            employeeLocalId,employeeRemoteId,"",requestedAt,
            JourneyCurrentStateSyncException("DEVICE_SESSION_MISSING",JourneyCurrentStateOutcome.NETWORK_ERROR)
        )
        val pendingBefore=journeyDao.pendingCountForEmployee(employeeLocalId)>0
        val localBeforeFlush=journeyDao.pendingForEmployee(employeeLocalId,1).firstOrNull()
            ?.let{journeyDao.findByLocalId(it.journeyLocalId)}?:journeyDao.latestForEmployee(employeeLocalId)
        stateLog(
            employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,localBeforeFlush?.workDate.orEmpty(),
            localBeforeFlush?.status.orEmpty(),pendingBefore,null,null,null,null,localBeforeFlush?.status.orEmpty(),"STARTED"
        )
        val blockedBeforeFlush=localBeforeFlush
        if(pendingBefore&&blockedBeforeFlush!=null&&blockedBeforeFlush.syncStatus in setOf("CONFLICTO","RECHAZADA")){
            val result=JourneyCurrentStateRefreshResult(
                blockedBeforeFlush.workDate,
                blockedBeforeFlush.remoteId!=null,
                blockedBeforeFlush.syncVersion,
                JourneyCurrentStateOutcome.CONFLICT
            )
            stateLog(employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,result.workDate,blockedBeforeFlush.status,true,null,null,null,blockedBeforeFlush.syncVersion,blockedBeforeFlush.status,result.finalResult.name)
            return result
        }

        var flushConflict=false
        var flushRemoteVersion:Long?=null
        var flushHttpStatus:Int?=null
        try {
            var processed=0
            while(processed<100){
                val outbox=journeyDao.pendingForEmployee(employeeLocalId,1).firstOrNull()?:break
                val knownVersion=AttendanceKnownVersionPolicy.select(
                    journeyDao.findByLocalId(outbox.journeyLocalId)?.syncVersion,
                    AttendanceOutboxVersionRebaser.versionFrom(outbox)
                )
                val outbound=AttendanceOutboxVersionRebaser.rebase(outbox,knownVersion)
                val result=gateway.upload(session.deviceId,session.credential,listOf(outbound))
                    .firstOrNull{it.idempotencyKey==outbox.idempotencyKey}?:break
                flushHttpStatus=200
                val now=System.currentTimeMillis()
                when(result.result){
                    "accepted","duplicate"->{
                        val remote=result.remote?:break
                        flushRemoteVersion=remote.version
                        val hydration=journeyDao.acknowledgeRemoteOperation(
                            outbox,remote.id,remote.status,remote.startedAt,remote.pauseStartedAt,remote.pauseEndedAt,
                            remote.finishedAt,remote.workedMinutes,remote.breakMinutes,remote.version,remote.rawJson,now
                        )
                        if(hydration.decision==JourneyRemoteHydrationDecision.VERSION_CONFLICT)flushConflict=true
                    }
                    "conflict"->{
                        journeyDao.rejectRemoteOperation(outbox,"CONFLICTO",result.errorCode?:"VERSION_CONFLICT",result.rawRemote,now)
                        flushRemoteVersion=result.version
                        flushConflict=true
                    }
                    else->{
                        journeyDao.rejectRemoteOperation(outbox,"RECHAZADA",result.errorCode?:"REJECTED",result.rawRemote,now)
                        flushConflict=true
                    }
                }
                processed++
                if(flushConflict)break
            }
        }catch(error:Exception){
            return cachedFallbackOrThrow(employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,error)
        }

        val pendingAfter=journeyDao.pendingCountForEmployee(employeeLocalId)>0
        val blockedLocal=journeyDao.pendingForEmployee(employeeLocalId,1).firstOrNull()
            ?.let{journeyDao.findByLocalId(it.journeyLocalId)}?:localBeforeFlush
        if(flushConflict){
            val result=JourneyCurrentStateRefreshResult(blockedLocal?.workDate.orEmpty(),true,flushRemoteVersion,JourneyCurrentStateOutcome.CONFLICT)
            stateLog(employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,result.workDate,blockedLocal?.status.orEmpty(),pendingAfter,flushHttpStatus,true,blockedLocal?.status,flushRemoteVersion,blockedLocal?.status.orEmpty(),result.finalResult.name)
            return result
        }
        if(pendingAfter){
            val result=JourneyCurrentStateRefreshResult(blockedLocal?.workDate.orEmpty(),false,null,JourneyCurrentStateOutcome.LOCAL_PENDING)
            stateLog(employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,result.workDate,blockedLocal?.status.orEmpty(),true,flushHttpStatus,false,null,null,blockedLocal?.status.orEmpty(),result.finalResult.name)
            return result
        }

        val current=try{
            gateway.fetchCurrentState(session.deviceId,session.credential,employeeRemoteId,requestedAt)
        }catch(error:Exception){
            return cachedFallbackOrThrow(employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,error)
        }
        val localBefore=journeyDao.find(employeeLocalId,current.workDate)
        if(!current.exists){
            val outcome=when(localBefore?.syncStatus){
                "PENDIENTE"->JourneyCurrentStateOutcome.LOCAL_PENDING
                "CONFLICTO","RECHAZADA"->JourneyCurrentStateOutcome.CONFLICT
                null->JourneyCurrentStateOutcome.REMOTE_EMPTY
                else->{
                    journeyDao.recordMissingRemoteStateConflict(employeeLocalId,employeeRemoteId,current.workDate,System.currentTimeMillis())
                    JourneyCurrentStateOutcome.CONFLICT
                }
            }
            val result=JourneyCurrentStateRefreshResult(current.workDate,false,null,outcome)
            stateLog(employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,current.workDate,localBefore?.status.orEmpty(),localBefore?.syncStatus=="PENDIENTE",200,false,null,null,localBefore?.status.orEmpty(),outcome.name)
            return result
        }

        val remote=requireNotNull(current.remote)
        val hydration=journeyDao.hydrateRemoteState(
            employeeLocalId,employeeRemoteId,session.deviceId,current.workDate,remote.id,remote.status,remote.startedAt,
            remote.pauseStartedAt,remote.pauseEndedAt,remote.finishedAt,remote.workedMinutes,remote.breakMinutes,
            remote.version,remote.rawJson,System.currentTimeMillis()
        )
        val outcome=when(hydration.decision){
            JourneyRemoteHydrationDecision.INSERT,JourneyRemoteHydrationDecision.UPDATE->JourneyCurrentStateOutcome.REMOTE_SUCCESS
            JourneyRemoteHydrationDecision.KEEP_LOCAL->JourneyCurrentStateOutcome.REMOTE_SUCCESS
            JourneyRemoteHydrationDecision.BLOCKED_PENDING->JourneyCurrentStateOutcome.LOCAL_PENDING
            JourneyRemoteHydrationDecision.VERSION_CONFLICT->JourneyCurrentStateOutcome.CONFLICT
        }
        val result=JourneyCurrentStateRefreshResult(current.workDate,true,remote.version,outcome)
        stateLog(
            employeeLocalId,employeeRemoteId,session.deviceId,requestedAt,current.workDate,
            hydration.localStatusBefore.orEmpty(),outcome==JourneyCurrentStateOutcome.LOCAL_PENDING,200,true,
            remote.status,remote.version,hydration.localStatusAfter.orEmpty(),outcome.name
        )
        return result
    }

    private fun validateRequestedAt(value:String){
        try{Instant.parse(value)}catch(error:Exception){
            throw JourneyCurrentStateSyncException("INVALID_REQUESTED_AT",JourneyCurrentStateOutcome.CONFLICT,error)
        }
    }

    private suspend fun cachedFallbackOrThrow(
        employeeLocalId:Int,employeeRemoteId:String,deviceId:String,requestedAt:String,error:Exception
    ):JourneyCurrentStateRefreshResult{
        val pending=journeyDao.pendingCountForEmployee(employeeLocalId)>0
        val local=journeyDao.latestForEmployee(employeeLocalId)
        val httpStatus=(error as? AttendanceSyncHttpException)?.status
        val expectedWorkDate=Instant.parse(requestedAt).atZone(ZoneId.systemDefault()).toLocalDate().toString()
        when(JourneyCurrentStateFallbackPolicy.outcome(pending,local?.syncStatus,local?.workDate,expectedWorkDate)){
         JourneyCurrentStateOutcome.LOCAL_PENDING->{
            val result=JourneyCurrentStateRefreshResult(local?.workDate.orEmpty(),local?.remoteId!=null,local?.syncVersion,JourneyCurrentStateOutcome.LOCAL_PENDING)
            stateLog(employeeLocalId,employeeRemoteId,deviceId,requestedAt,result.workDate,local?.status.orEmpty(),true,httpStatus,null,null,null,local?.status.orEmpty(),result.finalResult.name)
            return result
         }
         JourneyCurrentStateOutcome.LOCAL_CACHE->{
            requireNotNull(local)
            val result=JourneyCurrentStateRefreshResult(local.workDate,local.remoteId!=null,local.syncVersion,JourneyCurrentStateOutcome.LOCAL_CACHE)
            stateLog(employeeLocalId,employeeRemoteId,deviceId,requestedAt,result.workDate,local.status,false,httpStatus,null,null,null,local.status,result.finalResult.name)
            return result
         }
         else->Unit
        }
        stateLog(employeeLocalId,employeeRemoteId,deviceId,requestedAt,local?.workDate.orEmpty(),local?.status.orEmpty(),false,httpStatus,null,null,null,local?.status.orEmpty(),JourneyCurrentStateOutcome.NETWORK_ERROR.name)
        throw JourneyCurrentStateSyncException("NETWORK_ERROR",JourneyCurrentStateOutcome.NETWORK_ERROR,error)
    }

    private fun stateLog(
        employeeLocalId:Int,employeeRemoteId:String,deviceId:String,requestedAt:String,workDate:String,
        localStatusBefore:String,localPending:Boolean,httpStatus:Int?,remoteExists:Boolean?,remoteStatus:String?,
        remoteVersion:Long?,localStatusAfter:String,finalResult:String
    ){
        if(!BuildConfig.DEBUG)return
        Log.d(
            "JOURNEY_STATE_SYNC",
            "employeeLocalId=$employeeLocalId employeeRemoteId=$employeeRemoteId deviceId=$deviceId requestedAt=$requestedAt " +
                "workDate=$workDate localStatusBefore=$localStatusBefore localPending=$localPending httpStatus=${httpStatus?:""} " +
                "remoteExists=${remoteExists?:""} remoteStatus=${remoteStatus.orEmpty()} remoteVersion=${remoteVersion?:""} " +
                "localStatusAfter=$localStatusAfter finalResult=$finalResult"
        )
    }
}
