package com.example.controlhorario.device

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object EmployeeUploadScheduler{
 fun enqueueImmediate(context:Context){
  val request=OneTimeWorkRequestBuilder<EmployeeUploadWorker>().setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build()
  WorkManager.getInstance(context).enqueueUniqueWork("employee-upload-immediate",ExistingWorkPolicy.APPEND_OR_REPLACE,request)
 }
}
