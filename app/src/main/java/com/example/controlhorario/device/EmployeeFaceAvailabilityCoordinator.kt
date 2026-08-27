package com.example.controlhorario.device

import android.content.Context
import com.example.controlhorario.R
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.model.Employee
import com.example.controlhorario.security.DeviceIdentityManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

fun interface TargetedEmployeeSyncGateway {
    suspend fun sync(employeeCode: String)
}

enum class FaceAvailabilityResult { LOCAL, SYNCED, NOT_REGISTERED }

class EmployeeFaceAvailabilityCoordinator(
    private val faceExists: suspend (Int) -> Boolean,
    private val targetedSync: TargetedEmployeeSyncGateway
) {
    private val mutex = Mutex()

    suspend fun ensure(employee: Employee): FaceAvailabilityResult = mutex.withLock {
        if (faceExists(employee.id)) return FaceAvailabilityResult.LOCAL
        targetedSync.sync(employee.employeeCode)
        if (faceExists(employee.id)) FaceAvailabilityResult.SYNCED else FaceAvailabilityResult.NOT_REGISTERED
    }
}

class AndroidTargetedEmployeeSyncGateway(
    context: Context,
    private val database: AppDatabase
) : TargetedEmployeeSyncGateway {
    private val appContext = context.applicationContext

    override suspend fun sync(employeeCode: String) = withContext(Dispatchers.IO) {
        val identity = DeviceIdentityManager(appContext)
        val deviceId = requireNotNull(identity.deviceId) { "device_not_enrolled" }
        val credential = requireNotNull(identity.credential()) { "device_credential_missing" }
        EmployeeSyncRepository(database).syncEmployeeFace(
            EmployeeSyncClient(appContext.getString(R.string.employee_sync_url)),
            deviceId,
            credential,
            employeeCode
        )
        Unit
    }
}
