package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeBiometricDao
import com.example.controlhorario.database.EmployeeBiometricEntity
import com.example.controlhorario.database.EmployeeBiometricReplacement
import kotlinx.coroutines.flow.Flow

data class EmployeeBiometricLookup(
    val record: EmployeeBiometricEntity?,
    val rowsFound: Int
)

class EmployeeBiometricRepository(
    private val dao: EmployeeBiometricDao
) {
    fun getAll(): Flow<List<EmployeeBiometricEntity>> = dao.getAll()
    fun getByEmployee(employeeId: Int): Flow<List<EmployeeBiometricEntity>> = dao.getByEmployee(employeeId)

    /** Reads Room on demand; this repository does not retain a biometric template cache. */
    suspend fun getActiveByEmployeeWithMetadata(employeeId: Int): EmployeeBiometricLookup {
        val rows = dao.getActiveRowsByEmployee(employeeId)
        return EmployeeBiometricLookup(
            record = rows.firstOrNull(),
            rowsFound = rows.size
        )
    }

    suspend fun getActiveByEmployee(employeeId: Int): EmployeeBiometricEntity? =
        getActiveByEmployeeWithMetadata(employeeId).record

    suspend fun replaceForEmployee(entity: EmployeeBiometricEntity): EmployeeBiometricReplacement =
        dao.replaceForEmployee(entity)
}
