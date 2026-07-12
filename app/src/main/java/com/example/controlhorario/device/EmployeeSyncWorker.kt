package com.example.controlhorario.device
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.security.DeviceIdentityManager

class EmployeeSyncWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
 override suspend fun doWork():Result=runCatching{
  val identity=DeviceIdentityManager(applicationContext);val id=identity.deviceId?:return Result.failure();val credential=identity.credential()?:return Result.failure()
  val endpoint=applicationContext.getString(R.string.device_enrollment_url);val db=DatabaseProvider.getDatabase(applicationContext)
  EmployeeSyncRepository(db).replaceFromServer(DeviceEnrollmentClient(endpoint).employees(id,credential));db.deviceEnrollmentDao().markSynced(id,System.currentTimeMillis());Result.success()
 }.getOrElse{if(runAttemptCount<5)Result.retry()else Result.failure()}
}
