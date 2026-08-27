package com.example.controlhorario.device

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object DeviceSyncScheduler{
 const val IMMEDIATE_WORK="employee-sync-immediate"
 const val PERIODIC_WORK="employee-sync-periodic"
 fun start(context:Context){
  val constraints=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build()
  val manager=WorkManager.getInstance(context)
  val immediate=OneTimeWorkRequestBuilder<EmployeeSyncWorker>().setConstraints(constraints).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build()
  val periodic=PeriodicWorkRequestBuilder<EmployeeSyncWorker>(6,TimeUnit.HOURS).setConstraints(constraints).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build()
  manager.enqueueUniqueWork(IMMEDIATE_WORK,ExistingWorkPolicy.KEEP,immediate)
  manager.enqueueUniquePeriodicWork(PERIODIC_WORK,ExistingPeriodicWorkPolicy.UPDATE,periodic)
  Log.d("EmployeeSync","WorkManager programado: immediate_id=${immediate.id}, periodic_id=${periodic.id}, network=CONNECTED, interval=6h")
 }
}
