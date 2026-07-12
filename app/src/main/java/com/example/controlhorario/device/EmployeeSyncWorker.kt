package com.example.controlhorario.device

import android.content.Context
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
  val id=identity.deviceId?:return Result.failure()
  val credential=identity.credential()?:return Result.failure()
  return try{
   val client=EmployeeSyncClient(applicationContext.getString(R.string.employee_sync_url))
   EmployeeSyncRepository(DatabaseProvider.getDatabase(applicationContext)).sync(client,id,credential)
   Result.success()
  }catch(error:Exception){when(EmployeeSyncRetryPolicy.decide(error,runAttemptCount)){EmployeeSyncFailureDecision.RETRY->Result.retry();EmployeeSyncFailureDecision.FAILURE->Result.failure()}}
 }
}
