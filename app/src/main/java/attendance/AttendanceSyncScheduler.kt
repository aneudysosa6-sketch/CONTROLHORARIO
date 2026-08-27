package com.example.controlhorario.attendance

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import java.util.concurrent.TimeUnit

object AttendanceSyncScheduler{
 private const val IMMEDIATE="attendance-sync-immediate";private const val PERIODIC="attendance-sync-periodic"
 fun enqueue(context:Context){val c=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build();WorkManager.getInstance(context).enqueueUniqueWork(IMMEDIATE,ExistingWorkPolicy.APPEND_OR_REPLACE,OneTimeWorkRequestBuilder<AttendanceSyncWorker>().setConstraints(c).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build())}
 fun start(context:Context){enqueue(context);val c=Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build();WorkManager.getInstance(context).enqueueUniquePeriodicWork(PERIODIC,ExistingPeriodicWorkPolicy.UPDATE,PeriodicWorkRequestBuilder<AttendanceSyncWorker>(6,TimeUnit.HOURS).setConstraints(c).setBackoffCriteria(BackoffPolicy.EXPONENTIAL,30,TimeUnit.SECONDS).build())}
}
