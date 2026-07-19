package com.example.controlhorario.repository

import android.util.Log
import com.example.controlhorario.database.EmployeeDao
import com.example.controlhorario.model.Employee
import kotlinx.coroutines.flow.Flow

class EmployeeRepository(
    private val employeeDao: EmployeeDao
) {
    fun getAllEmployees(): Flow<List<Employee>> = employeeDao.getAllEmployees()

    fun getEmployeeById(employeeId: Int): Flow<Employee?> = employeeDao.getEmployeeById(employeeId)

    suspend fun findActiveByLocalId(employeeId: Int): Employee? =
        employeeDao.findByLocalId(employeeId)?.takeIf { it.isActive }

    suspend fun findForEdit(employeeKey: String): Employee? =
        employeeDao.findByRemoteId(employeeKey) ?: employeeKey.toIntOrNull()?.let { employeeDao.findByLocalId(it) }

    suspend fun findByEmployeeCode(code: String): Employee? {
        val normalized = code.filter { it.isDigit() }.padStart(5, '0')
        val employeeByCode = employeeDao.findByEmployeeCode(normalized)
        val employeeByPin = if (employeeByCode == null) employeeDao.findByPin(normalized) else null
        val employee = employeeByCode ?: employeeByPin
        Log.d(
            "EMPLOYEE_LOOKUP",
            "layer=Room codeLength=${normalized.length} matchedBy=" +
                when {
                    employeeByCode != null -> "employeeCode"
                    employeeByPin != null -> "pin"
                    else -> "none"
                } + " employeeId=${employee?.id} active=${employee?.isActive}"
        )
        return employee
    }

    suspend fun findAnyByEmployeeCode(code: String): Employee? {
        val normalized = code.filter { it.isDigit() }.padStart(5, '0')
        return employeeDao.findAnyByEmployeeCode(normalized) ?: employeeDao.findAnyByPin(normalized)
    }

    fun getEmployeesByDepartments(departmentIds: List<Int>): Flow<List<Employee>> =
        employeeDao.getEmployeesByDepartments(if (departmentIds.isEmpty()) listOf(-1) else departmentIds)

    fun getEmployeesByBranch(branchId: Int): Flow<List<Employee>> =
        employeeDao.getEmployeesByBranch(branchId)

    suspend fun setEmployeeActive(employeeId: Int, active: Boolean) {
        employeeDao.setEmployeeActive(employeeId, active)
    }

    suspend fun setJornadaEnabled(employeeId: Int, enabled: Boolean) {
        employeeDao.setJornadaEnabled(employeeId, enabled)
    }

    suspend fun addEmployee(employee: Employee): String {
        val code = if (employee.employeeCode.isNotBlank()) {
            employee.employeeCode.filter { it.isDigit() }.padStart(5, '0')
        } else {
            generateNextEmployeeCode()
        }

        val employeeToSave = employee.copy(
            employeeCode = code,
            pin = code,
            updatedAt = System.currentTimeMillis()
        )

        employeeDao.insertEmployee(employeeToSave)
        return code
    }

    suspend fun updateEmployee(employee: Employee) {
        require(employee.id > 0) { "No se puede editar un empleado sin id local" }
        employeeDao.updateEmployee(employee)
    }

    suspend fun markFingerprintRegistered(employeeId: Int, registeredAt: String, registeredBy: String) {
        employeeDao.markFingerprintRegistered(
            employeeId = employeeId,
            registeredAt = registeredAt,
            registeredBy = registeredBy
        )
    }

    private suspend fun generateNextEmployeeCode(): String {
        val lastCode = employeeDao.getLastEmployeeCode()
        val lastNumber = lastCode?.toIntOrNull() ?: 0
        return (lastNumber + 1).toString().padStart(5, '0')
    }
}
