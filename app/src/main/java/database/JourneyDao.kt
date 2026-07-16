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

@Dao interface JourneyDao {
 @Query("SELECT * FROM journeys WHERE employeeLocalId=:employeeId AND workDate=:workDate LIMIT 1") suspend fun find(employeeId:Int,workDate:String):JourneyEntity?
 @Query("SELECT * FROM journeys WHERE employeeLocalId=:employeeId AND workDate=:workDate LIMIT 1") fun observe(employeeId:Int,workDate:String):Flow<JourneyEntity?>
 @Query("SELECT * FROM journeys ORDER BY workDate DESC, updatedAt DESC") fun observeAll():Flow<List<JourneyEntity>>
 @Insert suspend fun insertJourney(value:JourneyEntity):Long
 @Update suspend fun updateJourney(value:JourneyEntity)
 @Insert suspend fun insertOutbox(value:JourneyOutboxEntity):Long
 @Insert suspend fun insertLegacy(value:AttendanceEntity)
 @Query("SELECT * FROM journey_outbox WHERE state='PENDIENTE' AND nextRetryAt<=:now ORDER BY id LIMIT :limit") suspend fun pending(now:Long,limit:Int=50):List<JourneyOutboxEntity>
 @Query("UPDATE journey_outbox SET state='ENVIADA',sentAt=:now,lastError='' WHERE id=:id") suspend fun markSent(id:Long,now:Long)
 @Query("UPDATE journey_outbox SET state=:state,attempts=attempts+1,nextRetryAt=:nextRetry,lastError=:error WHERE id=:id") suspend fun markFailed(id:Long,state:String,nextRetry:Long,error:String)
 @Query("UPDATE journeys SET remoteId=:remoteId,status=:status,startedAt=:startedAt,pauseStartedAt=:pauseStartedAt,pauseEndedAt=:pauseEndedAt,finishedAt=:finishedAt,workedMinutes=:workedMinutes,breakMinutes=:breakMinutes,syncStatus='ENVIADA',syncVersion=:version,lastSyncedAt=:now,updatedAt=:now WHERE localId=:localId") suspend fun applyRemote(localId:Int,remoteId:String?,status:String,startedAt:String?,pauseStartedAt:String?,pauseEndedAt:String?,finishedAt:String?,workedMinutes:Int,breakMinutes:Int,version:Long,now:Long)
 @Insert suspend fun insertConflict(value:JourneyConflictEntity)
 @Transaction suspend fun recordAction(employeeLocalId:Int,employeeRemoteId:String,employeeName:String,deviceId:String,branchId:String?,workDate:String,occurredAt:String,action:JourneyAction,jornadaEnabled:Boolean,proof:JourneyBiometricProof,proofSignature:String):LocalJourneyResult {
  require(jornadaEnabled){"ATTENDANCE_DISABLED"};require(proof.employeeLocalId==employeeLocalId&&proof.deviceId==deviceId&&proof.action==action){"BIOMETRIC_PROOF_INVALID"}
  val existing=find(employeeLocalId,workDate);val current=existing?.toSnapshot()?:JourneySnapshot();val transition=JourneyStateEngine.apply(current,action,occurredAt);require(transition.accepted){transition.errorCode?:"INVALID_TRANSITION"}
  val updated=(existing?:JourneyEntity(employeeLocalId=employeeLocalId,employeeRemoteId=employeeRemoteId,deviceId=deviceId,workDate=workDate)).fromSnapshot(transition.snapshot).copy(syncStatus="PENDIENTE",updatedAt=System.currentTimeMillis(),jornadaEnabledSnapshot=jornadaEnabled,startBranchId=existing?.startBranchId?:branchId,endBranchId=if(action==JourneyAction.FINALIZAR)branchId else existing?.endBranchId)
  val localId=if(existing==null)insertJourney(updated).toInt()else{updateJourney(updated);updated.localId};val key=UUID.randomUUID().toString()
  val payload=JSONObject().put("contract_version",2).put("employee_remote_id",employeeRemoteId).put("action",action.name).put("occurred_at",occurredAt).put("work_date",workDate).put("branch_id",branchId).put("biometric_proof_id",proof.id).put("biometric_proof_issued_at",proof.issuedAt).put("biometric_proof_expires_at",proof.expiresAt).put("biometric_proof_signature",proofSignature).put("idempotency_key",key).put("known_version",existing?.syncVersion?:0).toString()
  val outboxId=insertOutbox(JourneyOutboxEntity(journeyLocalId=localId,operation=action.name,idempotencyKey=key,payload=payload));insertLegacy(AttendanceEntity(employeeId=employeeLocalId,employeeName=employeeName,date=workDate,time=occurredAt.substringAfter('T').take(8),actionType=action.legacyAction(),biometricVerified=true,deviceName="2Connect USB Fingerprint Scanner",notes="RC2 offline; outbox=$key"));return LocalJourneyResult(if(existing==null)updated.copy(localId=localId)else updated,outboxId)
 }
}
private fun JourneyEntity.toSnapshot()=JourneySnapshot(JourneyStatus.valueOf(status),startedAt,pauseStartedAt,pauseEndedAt,finishedAt,workedMinutes,breakMinutes)
private fun JourneyEntity.fromSnapshot(s:JourneySnapshot)=copy(status=s.status.name,startedAt=s.startedAt,pauseStartedAt=s.pauseStartedAt,pauseEndedAt=s.pauseEndedAt,finishedAt=s.finishedAt,workedMinutes=s.workedMinutes,breakMinutes=s.breakMinutes)
private fun JourneyAction.legacyAction()=when(this){JourneyAction.INICIAR->"INICIO_JORNADA";JourneyAction.PAUSAR->"PAUSA";JourneyAction.REANUDAR->"REANUDAR";JourneyAction.FINALIZAR->"FIN_JORNADA"}
