package com.example.controlhorario.device

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.security.DeviceIdentityManager
import java.io.IOException

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
 val identity=DeviceIdentityManager(applicationContext)
  Log.d(TAG,"WorkManager inició EmployeeSyncWorker: attempt=$runAttemptCount, worker_id=$id")
  val id=identity.deviceId?:run{Log.e(TAG,"WorkManager aborta: device_id ausente");return Result.failure()}
  val credential=identity.credential()?:run{Log.e(TAG,"WorkManager aborta: credencial ausente para device_id=$id");return Result.failure()}
  Log.d(TAG,"WorkManager identidad disponible: device_id=$id, credential_present=true")
  return try{
   val client=EmployeeSyncClient(applicationContext.getString(R.string.employee_sync_url))
   val summary=EmployeeSyncRepository(DatabaseProvider.getDatabase(applicationContext)).sync(client,id,credential)
   Log.d(TAG,"WorkManager éxito: $summary")
   Result.success()
  }catch(error:Exception){val decision=EmployeeSyncRetryPolicy.decide(error,runAttemptCount);Log.e(TAG,"WorkManager excepción completa; decision=$decision, attempt=$runAttemptCount",error);when(decision){EmployeeSyncFailureDecision.RETRY->Result.retry();EmployeeSyncFailureDecision.FAILURE->Result.failure()}}
 }
 private companion object{const val TAG="EmployeeSync"}
}
