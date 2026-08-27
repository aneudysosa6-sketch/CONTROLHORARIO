package com.example.controlhorario.device

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.messages.EmployeeMessageInbox
import com.example.controlhorario.face.PendingFaceEnrollmentCountStore
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.security.TerminalAuthorizationManager
import java.io.IOException
import java.time.Instant

enum class EmployeeSyncFailureDecision{RETRY,FAILURE}
object EmployeeSyncRetryPolicy{
 fun decide(error:Throwable,attempt:Int)=when(error){
  is DeviceEnrollmentHttpException->if(error.statusCode>=500||error.statusCode==429)EmployeeSyncFailureDecision.RETRY else EmployeeSyncFailureDecision.FAILURE
  is IOException->EmployeeSyncFailureDecision.RETRY
  else->if(attempt<3)EmployeeSyncFailureDecision.RETRY else EmployeeSyncFailureDecision.FAILURE
 }
}

class EmployeeSyncWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
 override suspend fun doWork():Result{
  TerminalAuthorizationManager.init(applicationContext)
  val identity=DeviceIdentityManager(applicationContext)
  Log.d(TAG,"WorkManager inició EmployeeSyncWorker: attempt=$runAttemptCount, worker_id=$id")
  val id=identity.deviceId?:run{Log.e(TAG,"WorkManager aborta: device_id ausente");return Result.failure()}
  val credential=identity.credential()?:run{Log.e(TAG,"WorkManager aborta: credencial ausente para device_id=$id");return Result.failure()}
  Log.d(TAG,"WorkManager identidad de dispositivo disponible")
  return try{
   val database=DatabaseProvider.getDatabase(applicationContext)
   val client=EmployeeSyncClient(applicationContext.getString(R.string.employee_sync_url))
   val summary=EmployeeSyncRepository(database).sync(client,id,credential)
   summary.authorization?.let {
    TerminalAuthorizationManager.recordAuthorized(it.validatedAt,it.credentialExpiresAt,it.offlineLeaseExpiresAt)
   } ?: database.deviceEnrollmentDao().current()?.credentialExpiresAt?.let {
    TerminalAuthorizationManager.recordAuthorizedWithCredentialLease(Instant.now().toString(),it)
   }
   EmployeeMessageInbox.reconcilePreloaded(applicationContext,summary.messages)
   PendingFaceEnrollmentCountStore.update(applicationContext,summary.pendingFaceCount)
   Log.d(TAG,"WorkManager éxito: $summary")
   Result.success()
  }catch(error:Exception){
   if(error is DeviceEnrollmentHttpException&&error.statusCode in setOf(401,403)){
    val reason=if(error.statusCode==403)"DEVICE_REVOKED" else "DEVICE_CREDENTIAL_INVALID"
    TerminalAuthorizationManager.block(reason)
   }
   val decision=EmployeeSyncRetryPolicy.decide(error,runAttemptCount)
   Log.e(TAG,"WorkManager excepción completa; decision=$decision, attempt=$runAttemptCount",error)
   when(decision){EmployeeSyncFailureDecision.RETRY->Result.retry();EmployeeSyncFailureDecision.FAILURE->Result.failure()}
  }
 }
 private companion object{const val TAG="EmployeeSync"}
}
