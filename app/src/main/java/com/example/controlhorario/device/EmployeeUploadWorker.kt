package com.example.controlhorario.device

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.security.DeviceIdentityManager

class EmployeeUploadWorker(context:Context,params:WorkerParameters):CoroutineWorker(context,params){
 override suspend fun doWork():Result{
  val identity=DeviceIdentityManager(applicationContext);val deviceId=identity.deviceId?:return Result.failure();val credential=identity.credential()?:return Result.failure();val db=DatabaseProvider.getDatabase(applicationContext);val outbox=db.employeeSyncOutboxDao();val employeeDao=db.employeeDao();val items=outbox.pending(System.currentTimeMillis());if(items.isEmpty())return Result.success()
  return try{items.forEach{outbox.markSyncing(it.id,System.currentTimeMillis());employeeDao.setSyncStatus(it.employeeLocalId,"SYNCING")};val results=EmployeeUploadClient(applicationContext.getString(R.string.employee_upsert_url)).upload(deviceId,credential,items);results.forEach{result->val item=items.firstOrNull{it.idempotencyKey==result.key}?:return@forEach;if(result.result=="accepted"||result.result=="duplicate"){employeeDao.markRemoteSynced(item.employeeLocalId,requireNotNull(result.remoteId),result.updatedAt.orEmpty(),System.currentTimeMillis());outbox.markSynced(item.id,System.currentTimeMillis());Log.d("EMPLOYEE_REMOTE_UPDATE","localEmployeeId=${item.employeeLocalId} remoteId=${result.remoteId} status=SYNCED")}else{employeeDao.setSyncStatus(item.employeeLocalId,"FAILED",result.error);outbox.markFailed(item.id,result.error?:"REJECTED",Long.MAX_VALUE,System.currentTimeMillis())}};Result.success()}catch(error:Exception){items.forEach{outbox.markFailed(it.id,error.message?:"NETWORK_ERROR",System.currentTimeMillis()+30_000,System.currentTimeMillis());employeeDao.setSyncStatus(it.employeeLocalId,"FAILED",error.message)};Log.e("EMPLOYEE_UPLOAD_WORKER","upload failed",error);if(error is EmployeeUploadHttpException&&error.status in 400..499)Result.failure()else Result.retry()}
 }
}
