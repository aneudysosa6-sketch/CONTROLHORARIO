package com.example.controlhorario.repository

import android.util.Log
import com.example.controlhorario.database.EmployeeDao
import com.example.controlhorario.database.EmployeeSyncOutboxDao
import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import com.example.controlhorario.model.Employee
import kotlinx.coroutines.flow.Flow
import org.json.JSONObject
import java.util.UUID

class EmployeeRepository(
    private val employeeDao: EmployeeDao,
    private val outboxDao: EmployeeSyncOutboxDao? = null
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

        val localId=employeeDao.insertEmployee(employeeToSave).toInt()
        queue(employeeToSave.copy(id=localId),"CREATE")
        Log.d("EMPLOYEE_LOCAL_SAVE","employeeId=$localId code=$code syncStatus=PENDING operation=CREATE")
        return code
    }

    suspend fun updateEmployee(employee: Employee) {
        require(employee.id > 0) { "No se puede editar un empleado sin id local" }
        val pending=employee.copy(syncStatus="PENDING",lastSyncError=null,updatedAt=System.currentTimeMillis())
        employeeDao.updateEmployee(pending)
        queue(pending,"UPDATE")
        Log.d("EMPLOYEE_LOCAL_SAVE","employeeId=${pending.id} code=${pending.employeeCode} syncStatus=PENDING operation=UPDATE")
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

    private suspend fun queue(employee:Employee,operation:String){
        val outbox=outboxDao?:return
        val key=UUID.randomUUID().toString()
        val payload=JSONObject().put("idempotency_key",key).put("operation",operation).put("local_employee_id",employee.id).put("remote_id",employee.remoteId).put("employee_code",employee.employeeCode).put("name",employee.nombre).put("phone",employee.telefono).put("email",employee.email).put("active",employee.isActive).put("updated_at",employee.updatedAt).toString()
        outbox.insert(EmployeeSyncOutboxEntity(employeeLocalId=employee.id,operation=operation,payloadJson=payload,idempotencyKey=key))
        Log.d("EMPLOYEE_OUTBOX","employeeId=${employee.id} remoteId=${employee.remoteId} code=${employee.employeeCode} operation=$operation syncStatus=PENDING idempotencyKey=$key")
    }

    suspend fun enqueueFaceEmbedding(employee: Employee, embedding: FloatArray) {
        require(embedding.size == 128 && embedding.all { it.isFinite() })
        val outbox = outboxDao ?: return
        val key = UUID.randomUUID().toString()
        val payload = JSONObject().put("idempotency_key", key).put("operation", "UPDATE")
            .put("local_employee_id", employee.id).put("remote_id", employee.remoteId)
            .put("employee_code", employee.employeeCode).put("name", employee.nombre)
            .put("phone", employee.telefono).put("email", employee.email).put("active", employee.isActive)
            .put("updated_at", System.currentTimeMillis()).put("face_embedding", org.json.JSONArray(embedding.toList())).toString()
        val outboxId = outbox.insert(EmployeeSyncOutboxEntity(employeeLocalId = employee.id, operation = "UPDATE", payloadJson = payload, idempotencyKey = key))
        Log.d(
            "FACE_EMBEDDING_FLOW",
            "stage=outbox employeeId=${employee.id} outboxId=$outboxId operation=UPDATE faceEmbeddingType=array dimension=${embedding.size}"
        )
    }
}
