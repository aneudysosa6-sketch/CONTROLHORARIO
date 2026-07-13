package com.example.controlhorario.attendance

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.database.JourneyConflictEntity
import com.example.controlhorario.database.AppEventEntity
import com.example.controlhorario.security.DeviceIdentityManager
import java.io.IOException

class AttendanceSyncWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
 override suspend fun doWork():Result{
  val identity=DeviceIdentityManager(applicationContext)
  val deviceId=identity.deviceId?:return Result.failure()
  val credential=identity.credential()?:return Result.failure()
  val database=DatabaseProvider.getDatabase(applicationContext)
  val dao=database.journeyDao()
  val pending=dao.pending(System.currentTimeMillis())
  if(pending.isEmpty())return Result.success()
  return try{
   val results=AttendanceSyncClient(applicationContext.getString(R.string.attendance_sync_url)).upload(deviceId,credential,pending)
   results.forEach{result->val item=pending.firstOrNull{it.idempotencyKey==result.idempotencyKey}?:return@forEach;val now=System.currentTimeMillis();when(result.result){
    "accepted","duplicate"->{result.remote?.let{dao.applyRemote(item.journeyLocalId,it.id,it.status,it.startedAt,it.pauseStartedAt,it.pauseEndedAt,it.finishedAt,it.workedMinutes,it.breakMinutes,result.version,now)};dao.markSent(item.id,now)}
    "conflict"->{dao.insertConflict(JourneyConflictEntity(journeyLocalId=item.journeyLocalId,idempotencyKey=item.idempotencyKey,localSnapshot=item.payload,remoteSnapshot=result.rawRemote,reason=result.errorCode?:"VERSION_CONFLICT"));dao.markFailed(item.id,"CONFLICTO",Long.MAX_VALUE,result.errorCode?:"VERSION_CONFLICT");database.appEventDao().saveEvent(AppEventEntity(title="Conflicto de jornada",description="Requiere resolución administrativa.",module="JORNADAS"))}
    else->{dao.markFailed(item.id,"RECHAZADA",Long.MAX_VALUE,result.errorCode?:"REJECTED");database.appEventDao().saveEvent(AppEventEntity(title="Error definitivo de sincronización",description=result.errorCode?:"Operación rechazada",module="JORNADAS"))}
   }};Result.success()
  }catch(error:Exception){val permanent=error is AttendanceSyncHttpException&&error.status in 400..499;pending.forEach{dao.markFailed(it.id,if(permanent)"RECHAZADA" else "PENDIENTE",if(permanent)Long.MAX_VALUE else System.currentTimeMillis()+backoff(it.attempts),error.message?:"NETWORK_ERROR")};if(permanent){database.appEventDao().saveEvent(AppEventEntity(title="Sincronización de jornada rechazada",description="El dispositivo o la operación requiere revisión.",module="JORNADAS"));Result.failure()}else Result.retry()}
 }
 private fun backoff(attempt:Int)=(30_000L shl attempt.coerceAtMost(8))
}
