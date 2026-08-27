package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Update
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.engine.JourneySnapshot
import com.example.controlhorario.engine.JourneyStateEngine
import com.example.controlhorario.engine.JourneyStatus
import com.example.controlhorario.ui.punch.JourneyBiometricProof
import kotlinx.coroutines.flow.Flow
import org.json.JSONObject
import java.util.UUID

data class LocalJourneyResult(val journey:JourneyEntity,val outboxId:Long)
enum class JourneyRemoteHydrationDecision { INSERT, UPDATE, KEEP_LOCAL, BLOCKED_PENDING, VERSION_CONFLICT }
data class JourneyRemoteHydrationResult(
 val decision:JourneyRemoteHydrationDecision,
 val localId:Int?,
 val localStatusBefore:String?,
 val localStatusAfter:String?,
 val localVersionBefore:Long?,
 val localVersionAfter:Long?
)

object JourneyRemoteHydrationPolicy {
 fun decide(local:JourneyEntity?,hasPendingOutbox:Boolean,remoteVersion:Long):JourneyRemoteHydrationDecision{
  require(remoteVersion>=0){"INVALID_REMOTE_VERSION"}
  return when{
   local==null->JourneyRemoteHydrationDecision.INSERT
   hasPendingOutbox->JourneyRemoteHydrationDecision.BLOCKED_PENDING
   else->JourneyRemoteHydrationDecision.UPDATE
  }
 }
}

@Dao interface JourneyDao {
 @Query("SELECT * FROM journeys WHERE employeeLocalId=:employeeId AND workDate=:workDate LIMIT 1") suspend fun find(employeeId:Int,workDate:String):JourneyEntity?
 @Query("SELECT * FROM journeys WHERE localId=:localId LIMIT 1") suspend fun findByLocalId(localId:Int):JourneyEntity?
 @Query("SELECT * FROM journeys WHERE employeeLocalId=:employeeId ORDER BY workDate DESC, updatedAt DESC LIMIT 1") suspend fun latestForEmployee(employeeId:Int):JourneyEntity?
 @Query("SELECT * FROM journeys WHERE employeeLocalId=:employeeId AND workDate=:workDate LIMIT 1") fun observe(employeeId:Int,workDate:String):Flow<JourneyEntity?>
 @Query("SELECT * FROM journeys ORDER BY workDate DESC, updatedAt DESC") fun observeAll():Flow<List<JourneyEntity>>
 @Insert suspend fun insertJourney(value:JourneyEntity):Long
 @Update suspend fun updateJourney(value:JourneyEntity)
 @Insert suspend fun insertOutbox(value:JourneyOutboxEntity):Long
 @Insert suspend fun insertLegacy(value:AttendanceEntity)
 @Query("SELECT * FROM journey_outbox WHERE state='PENDIENTE' AND nextRetryAt<=:now ORDER BY id LIMIT :limit") suspend fun pending(now:Long,limit:Int=50):List<JourneyOutboxEntity>
 @Query("SELECT o.* FROM journey_outbox o INNER JOIN journeys j ON j.localId=o.journeyLocalId WHERE j.employeeLocalId=:employeeLocalId AND o.state='PENDIENTE' ORDER BY o.id LIMIT :limit") suspend fun pendingForEmployee(employeeLocalId:Int,limit:Int=100):List<JourneyOutboxEntity>
 @Query("SELECT COUNT(*) FROM journey_outbox o INNER JOIN journeys j ON j.localId=o.journeyLocalId WHERE j.employeeLocalId=:employeeLocalId AND o.state='PENDIENTE'") suspend fun pendingCountForEmployee(employeeLocalId:Int):Int
 @Query("SELECT COUNT(*) FROM journey_outbox WHERE journeyLocalId=:journeyLocalId AND state='PENDIENTE'") suspend fun pendingCountForJourney(journeyLocalId:Int):Int
 @Query("UPDATE journey_outbox SET state='ENVIADA',sentAt=:now,lastError='' WHERE id=:id") suspend fun markSent(id:Long,now:Long)
 @Query("UPDATE journey_outbox SET state=:state,attempts=attempts+1,nextRetryAt=:nextRetry,lastError=:error WHERE id=:id") suspend fun markFailed(id:Long,state:String,nextRetry:Long,error:String)
 @Query("UPDATE journey_outbox SET state='RESUELTA_REMOTO',sentAt=COALESCE(sentAt,:now),lastError='' WHERE journeyLocalId=:journeyLocalId AND state IN ('CONFLICTO','RECHAZADA')") suspend fun resolveTerminalOutboxFromRemote(journeyLocalId:Int,now:Long):Int
 @Query("UPDATE journeys SET syncStatus=:state,updatedAt=:now WHERE localId=:localId") suspend fun markJourneySyncState(localId:Int,state:String,now:Long)
 @Query("UPDATE journeys SET remoteId=COALESCE(:remoteId,remoteId),syncVersion=:version,lastSyncedAt=:now WHERE localId=:localId") suspend fun recordRemoteAckMetadata(localId:Int,remoteId:String?,version:Long,now:Long)
 @Query("UPDATE journeys SET remoteId=:remoteId,status=:status,startedAt=:startedAt,pauseStartedAt=:pauseStartedAt,pauseEndedAt=:pauseEndedAt,finishedAt=:finishedAt,workedMinutes=:workedMinutes,breakMinutes=:breakMinutes,syncStatus='ENVIADA',syncVersion=:version,lastSyncedAt=:now,createdOffline=0,updatedAt=:now WHERE localId=:localId") suspend fun applyRemote(localId:Int,remoteId:String?,status:String,startedAt:String?,pauseStartedAt:String?,pauseEndedAt:String?,finishedAt:String?,workedMinutes:Int,breakMinutes:Int,version:Long,now:Long)
 @Insert suspend fun insertConflict(value:JourneyConflictEntity)
 @Query("SELECT COUNT(*) FROM journey_conflicts WHERE journeyLocalId=:journeyLocalId AND reason=:reason AND remoteSnapshot=:remoteSnapshot AND resolutionState='PENDIENTE'") suspend fun openConflictCount(journeyLocalId:Int,reason:String,remoteSnapshot:String):Int
 @Query("UPDATE journey_conflicts SET resolutionState='RESUELTO_REMOTO',resolvedAt=:now WHERE journeyLocalId=:journeyLocalId AND resolutionState='PENDIENTE'") suspend fun resolveOpenConflictsFromRemote(journeyLocalId:Int,now:Long):Int

 @Transaction suspend fun acknowledgeRemoteOperation(
  outbox:JourneyOutboxEntity,remoteId:String?,status:String,startedAt:String?,pauseStartedAt:String?,pauseEndedAt:String?,finishedAt:String?,workedMinutes:Int,breakMinutes:Int,version:Long,remoteSnapshot:String,now:Long
 ):JourneyRemoteHydrationResult{
  val local=findByLocalId(outbox.journeyLocalId)
  markSent(outbox.id,now)
  if(local==null)return JourneyRemoteHydrationResult(JourneyRemoteHydrationDecision.KEEP_LOCAL,null,null,null,null,null)
  if(pendingCountForJourney(local.localId)>0){
   recordRemoteAckMetadata(local.localId,remoteId,maxOf(local.syncVersion,version),now)
   return JourneyRemoteHydrationResult(JourneyRemoteHydrationDecision.BLOCKED_PENDING,local.localId,local.status,local.status,local.syncVersion,maxOf(local.syncVersion,version))
  }
  applyRemote(local.localId,remoteId,status,startedAt,pauseStartedAt,pauseEndedAt,finishedAt,workedMinutes,breakMinutes,version,now)
  resolveTerminalOutboxFromRemote(local.localId,now)
  resolveOpenConflictsFromRemote(local.localId,now)
  return JourneyRemoteHydrationResult(JourneyRemoteHydrationDecision.UPDATE,local.localId,local.status,status,local.syncVersion,version)
 }

 @Transaction suspend fun rejectRemoteOperation(outbox:JourneyOutboxEntity,state:String,error:String,remoteSnapshot:String,now:Long){
  markFailed(outbox.id,state,Long.MAX_VALUE,error)
  val local=findByLocalId(outbox.journeyLocalId)?:return
  if(state=="CONFLICTO")insertConflictOnce(local,outbox.idempotencyKey,remoteSnapshot,error)
  markJourneySyncState(local.localId,state,now)
 }

 @Transaction suspend fun hydrateRemoteState(
  employeeLocalId:Int,employeeRemoteId:String,deviceId:String,workDate:String,remoteId:String?,status:String,
  startedAt:String?,pauseStartedAt:String?,pauseEndedAt:String?,finishedAt:String?,workedMinutes:Int,breakMinutes:Int,
  version:Long,now:Long
 ):JourneyRemoteHydrationResult{
  val local=find(employeeLocalId,workDate)
  val pending=local?.let{pendingCountForJourney(it.localId)>0}?:false
  return when(val decision=JourneyRemoteHydrationPolicy.decide(local,pending,version)){
   JourneyRemoteHydrationDecision.INSERT->{
    val value=JourneyEntity(remoteId=remoteId,employeeLocalId=employeeLocalId,employeeRemoteId=employeeRemoteId,deviceId=deviceId,workDate=workDate,status=status,startedAt=startedAt,pauseStartedAt=pauseStartedAt,pauseEndedAt=pauseEndedAt,finishedAt=finishedAt,workedMinutes=workedMinutes,breakMinutes=breakMinutes,syncStatus="ENVIADA",syncVersion=version,lastSyncedAt=now,createdOffline=false,updatedAt=now)
    val id=insertJourney(value).toInt()
    JourneyRemoteHydrationResult(decision,id,null,status,null,version)
   }
   JourneyRemoteHydrationDecision.UPDATE->{
    val current=requireNotNull(local)
    val updated=current.copy(remoteId=remoteId?:current.remoteId,employeeRemoteId=employeeRemoteId,status=status,startedAt=startedAt,pauseStartedAt=pauseStartedAt,pauseEndedAt=pauseEndedAt,finishedAt=finishedAt,workedMinutes=workedMinutes,breakMinutes=breakMinutes,syncStatus="ENVIADA",syncVersion=version,lastSyncedAt=now,createdOffline=false,updatedAt=now)
    updateJourney(updated)
    resolveTerminalOutboxFromRemote(current.localId,now)
    resolveOpenConflictsFromRemote(current.localId,now)
    JourneyRemoteHydrationResult(decision,current.localId,current.status,status,current.syncVersion,version)
   }
   JourneyRemoteHydrationDecision.KEEP_LOCAL->{
    val current=requireNotNull(local)
    applyRemote(current.localId,remoteId?:current.remoteId,status,startedAt,pauseStartedAt,pauseEndedAt,finishedAt,workedMinutes,breakMinutes,version,now)
    resolveTerminalOutboxFromRemote(current.localId,now)
    resolveOpenConflictsFromRemote(current.localId,now)
    JourneyRemoteHydrationResult(decision,current.localId,current.status,status,current.syncVersion,version)
   }
   JourneyRemoteHydrationDecision.BLOCKED_PENDING->{
    val current=requireNotNull(local)
    JourneyRemoteHydrationResult(decision,current.localId,current.status,current.status,current.syncVersion,current.syncVersion)
   }
   JourneyRemoteHydrationDecision.VERSION_CONFLICT->{
    val current=requireNotNull(local)
    markJourneySyncState(current.localId,"CONFLICTO",now)
    JourneyRemoteHydrationResult(decision,current.localId,current.status,current.status,current.syncVersion,current.syncVersion)
   }
  }
 }

 @Transaction suspend fun recordMissingRemoteStateConflict(
  employeeLocalId:Int,employeeRemoteId:String,workDate:String,now:Long
 ):JourneyEntity?{
  val local=find(employeeLocalId,workDate)?:return null
  val remoteSnapshot=JSONObject().put("exists",false).put("work_date",workDate).toString()
  val key=UUID.nameUUIDFromBytes("current_state_missing|$employeeRemoteId|$workDate".toByteArray()).toString()
  insertConflictOnce(local,key,remoteSnapshot,"REMOTE_STATE_MISSING")
  markJourneySyncState(local.localId,"CONFLICTO",now)
  return local
 }

 @Transaction suspend fun recordAction(employeeLocalId:Int,employeeRemoteId:String,employeeCode:String,employeeName:String,deviceId:String,branchId:String?,departmentId:String?,workDate:String,occurredAt:String,action:JourneyAction,jornadaEnabled:Boolean,proof:JourneyBiometricProof,proofSignature:String):LocalJourneyResult {
  require(jornadaEnabled){"ATTENDANCE_DISABLED"};require(proof.employeeLocalId==employeeLocalId&&proof.deviceId==deviceId&&proof.action==action){"BIOMETRIC_PROOF_INVALID"}
  val existing=find(employeeLocalId,workDate);val current=existing?.toSnapshot()?:JourneySnapshot();val transition=JourneyStateEngine.apply(current,action,occurredAt);require(transition.accepted){transition.errorCode?:"INVALID_TRANSITION"}
  val updated=(existing?:JourneyEntity(employeeLocalId=employeeLocalId,employeeRemoteId=employeeRemoteId,deviceId=deviceId,workDate=workDate)).fromSnapshot(transition.snapshot).copy(syncStatus="PENDIENTE",updatedAt=System.currentTimeMillis(),jornadaEnabledSnapshot=jornadaEnabled,startBranchId=existing?.startBranchId?:branchId,endBranchId=if(action==JourneyAction.FINALIZAR)branchId else existing?.endBranchId)
  val localId=if(existing==null)insertJourney(updated).toInt()else{updateJourney(updated);updated.localId};val key=UUID.randomUUID().toString()
  val payload=JSONObject().put("contract_version",2).put("employee_remote_id",employeeRemoteId).put("employee_code",employeeCode).put("department_id",departmentId).put("action",action.name).put("occurred_at",occurredAt).put("work_date",workDate).put("branch_id",branchId).put("biometric_proof_id",proof.id).put("biometric_proof_issued_at",proof.issuedAt).put("biometric_proof_expires_at",proof.expiresAt).put("biometric_proof_signature",proofSignature).put("idempotency_key",key).put("known_version",existing?.syncVersion?:0).toString()
  val outboxId=insertOutbox(JourneyOutboxEntity(journeyLocalId=localId,operation=action.name,idempotencyKey=key,payload=payload));insertLegacy(AttendanceEntity(employeeId=employeeLocalId,employeeName=employeeName,date=workDate,time=occurredAt.substringAfter('T').take(8),actionType=action.legacyAction(),biometricVerified=true,deviceName="Verificación facial Android",notes="Validación facial local; outbox=$key"));return LocalJourneyResult(if(existing==null)updated.copy(localId=localId)else updated,outboxId)
 }

 private suspend fun insertConflictOnce(local:JourneyEntity,key:String,remoteSnapshot:String,reason:String){
  if(openConflictCount(local.localId,reason,remoteSnapshot)>0)return
  insertConflict(JourneyConflictEntity(journeyLocalId=local.localId,idempotencyKey=key,localSnapshot=local.conflictSnapshot(),remoteSnapshot=remoteSnapshot,reason=reason))
 }
}
private fun JourneyEntity.conflictSnapshot()=JSONObject().put("local_id",localId).put("remote_id",remoteId).put("employee_remote_id",employeeRemoteId).put("work_date",workDate).put("status",status).put("started_at",startedAt).put("pause_started_at",pauseStartedAt).put("pause_ended_at",pauseEndedAt).put("finished_at",finishedAt).put("worked_minutes",workedMinutes).put("break_minutes",breakMinutes).put("sync_status",syncStatus).put("sync_version",syncVersion).toString()
private fun JourneyEntity.toSnapshot()=JourneySnapshot(JourneyStatus.valueOf(status),startedAt,pauseStartedAt,pauseEndedAt,finishedAt,workedMinutes,breakMinutes)
private fun JourneyEntity.fromSnapshot(s:JourneySnapshot)=copy(status=s.status.name,startedAt=s.startedAt,pauseStartedAt=s.pauseStartedAt,pauseEndedAt=s.pauseEndedAt,finishedAt=s.finishedAt,workedMinutes=s.workedMinutes,breakMinutes=s.breakMinutes)
private fun JourneyAction.legacyAction()=when(this){JourneyAction.INICIAR->"INICIO_JORNADA";JourneyAction.PAUSAR->"PAUSA";JourneyAction.REANUDAR->"REANUDAR";JourneyAction.FINALIZAR->"FIN_JORNADA"}
