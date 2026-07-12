package com.example.controlhorario.device
import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit
object DeviceSyncScheduler{
 fun start(context:Context){val constraints=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build();val manager=WorkManager.getInstance(context)
  manager.enqueue(OneTimeWorkRequestBuilder<EmployeeSyncWorker>().setConstraints(constraints).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build())
  manager.enqueueUniquePeriodicWork("employee-sync",ExistingPeriodicWorkPolicy.UPDATE,PeriodicWorkRequestBuilder<EmployeeSyncWorker>(6,TimeUnit.HOURS).setConstraints(constraints).build())
 }
}
