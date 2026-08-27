package com.example.controlhorario.messages

import android.content.Context
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.example.controlhorario.R
import com.example.controlhorario.security.DeviceIdentityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.TimeUnit

class EmployeeMessageReceiptWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        val message = EmployeeMessageInbox.pendingReceipt(applicationContext) ?: return Result.success()
        val identity = DeviceIdentityManager(applicationContext)
        val deviceId = identity.deviceId ?: return Result.retry()
        val credential = identity.credential() ?: return Result.retry()
        return try {
            val confirmed = withContext(Dispatchers.IO) {
                EmployeeMessageReceiptClient(applicationContext.getString(R.string.attendance_sync_url))
                    .confirm(deviceId, credential, message.id, message.employeeRemoteId)
            }
            if (confirmed) {
                EmployeeMessageInbox.clearConfirmed(applicationContext, message.id)
                Result.success()
            } else {
                Result.retry()
            }
        } catch (error: EmployeeMessageReceiptHttpException) {
            if (error.status in 400..499) Result.failure() else Result.retry()
        } catch (_: Exception) {
            Result.retry()
        }
    }
}

object EmployeeMessageReceiptScheduler {
    private const val UNIQUE_WORK = "employee-message-receipt"

    fun enqueue(context: Context) {
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<EmployeeMessageReceiptWorker>()
            .setConstraints(constraints)
            .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
            .build()
        WorkManager.getInstance(context.applicationContext)
            .enqueueUniqueWork(UNIQUE_WORK, ExistingWorkPolicy.KEEP, request)
    }
}