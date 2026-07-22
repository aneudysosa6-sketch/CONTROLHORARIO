package com.example.controlhorario.repository

import android.util.Log
import androidx.room.withTransaction
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.database.EmployeeDao
import com.example.controlhorario.database.EmployeeSyncOutboxDao
import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import org.json.JSONObject
import java.util.UUID

class EmployeeRepository(
    private val employeeDao: EmployeeDao,
    private val outboxDao: EmployeeSyncOutboxDao? = null,
    private val roomDatabase: AppDatabase? = null
) {
    fun getAllEmployees(): Flow<List<Employee>> = employeeDao.getAllEmployees()

    fun getEmployeeById(employeeId: Int): Flow<Employee?> = employeeDao.getEmployeeById(employeeId)

    suspend fun findActiveByLocalId(employeeId: Int): Employee? =
        employeeDao.findByLocalId(employeeId)?.takeIf {
            it.isActive && it.remoteId != null
        }

    suspend fun findAnyByLocalId(employeeId: Int): Employee? = employeeDao.findByLocalId(employeeId)

    /** Exact employee-code lookup used by public face enrollment. */
    suspend fun findAnyByExactEmployeeCode(employeeCode: String): Employee? =
        employeeDao.findAnyByEmployeeCode(employeeCode)

    suspend fun findForEdit(employeeKey: String): Employee? =
        employeeDao.findByRemoteId(employeeKey) ?: employeeKey.toIntOrNull()?.let { employeeDao.findByLocalId(it) }

    suspend fun findByEmployeeCode(code: String): Employee? {
        val normalized = EmployeeCodePolicy.normalizeOrNull(code) ?: return null
        val candidates = EmployeeCodePolicy.lookupCandidates(normalized)
        val codeMatches = employeeDao.findByEmployeeCodes(candidates).distinctBy(Employee::id)
        val employee = codeMatches.singleOrNull()
        Log.d(
            "EMPLOYEE_LOOKUP",
            "layer=Room codeLength=${normalized.length} matchedBy=" +
                (if (employee != null) "employeeCode" else "none") +
                " employeeId=${employee?.id} active=${employee?.isActive} " +
                "synced=${employee?.syncStatus == "SYNCED"}"
        )
        return employee
    }

    suspend fun findAnyByEmployeeCode(code: String): Employee? {
        val normalized = EmployeeCodePolicy.normalizeOrNull(code) ?: return null
        val candidates = EmployeeCodePolicy.lookupCandidates(normalized)
        return employeeDao.findAnyByEmployeeCodes(candidates)
            .distinctBy(Employee::id)
            .singleOrNull()
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

    suspend fun addEmployee(employee: Employee): Int = EMPLOYEE_CREATION_MUTEX.withLock {
        mutationDatabase().withTransaction {
            val code = generateNextEmployeeCode()
            val candidates = EmployeeCodePolicy.lookupCandidates(code)
            check(employeeDao.findAnyByEmployeeCodes(candidates).isEmpty()) {
                "El código de empleado $code ya está reservado."
            }

            val employeeToSave = employee.copy(
                employeeCode = code,
                pin = "",
                remoteId = null,
                syncStatus = "PENDING",
                lastSyncError = null,
                updatedAt = System.currentTimeMillis()
            )

            val localId=employeeDao.insertNewEmployee(employeeToSave).toInt()
            queue(employeeToSave.copy(id=localId),"CREATE")
            Log.d("EMPLOYEE_LOCAL_SAVE","employeeId=$localId code=${EmployeeCodePolicy.maskForLog(code)} syncStatus=PENDING operation=CREATE")
            localId
        }
    }

    suspend fun updateEmployee(employee: Employee) {
        mutationDatabase().withTransaction {
            require(employee.id > 0) { "No se puede editar un empleado sin id local" }
            val code = requireNotNull(EmployeeCodePolicy.normalizeOrNull(employee.employeeCode)) {
                EmployeeCodePolicy.ERROR
            }
            requireNotNull(employeeDao.findByLocalId(employee.id)) {
                "No existe el empleado local ${employee.id}."
            }
            val candidates = EmployeeCodePolicy.lookupCandidates(code)
            val collisions = employeeDao.findAnyByEmployeeCodes(candidates)
                .distinctBy(Employee::id)
                .filter { it.id != employee.id }
            require(collisions.isEmpty()) {
                "El código de empleado $code ya está reservado."
            }
            val pending=employee.copy(
                employeeCode=code,
                pin="",
                syncStatus="PENDING",
                lastSyncError=null,
                updatedAt=System.currentTimeMillis()
            )
            employeeDao.updateEmployee(pending)
            queue(pending,"UPDATE")
            Log.d("EMPLOYEE_LOCAL_SAVE","employeeId=${pending.id} code=${EmployeeCodePolicy.maskForLog(pending.employeeCode)} syncStatus=PENDING operation=UPDATE")
        }
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
        return EmployeeCodePolicy.nextAvailableAfter(lastCode, employeeDao.getAllEmployeeCodes())
    }

    private fun mutationDatabase(): AppDatabase = checkNotNull(roomDatabase) {
        "AppDatabase es obligatoria para guardar empleado y outbox atómicamente."
    }

    private suspend fun queue(employee:Employee,operation:String){
        val outbox=checkNotNull(outboxDao){"EmployeeSyncOutboxDao es obligatorio para crear o editar empleados."}
        val code=requireNotNull(EmployeeCodePolicy.normalizeOrNull(employee.employeeCode)){EmployeeCodePolicy.ERROR}
        val key=UUID.randomUUID().toString()
        val payload=JSONObject().put("idempotency_key",key).put("operation",operation).put("local_employee_id",employee.id).put("remote_id",employee.remoteId).apply {
            // CREATE is allocated transactionally by Supabase. This Room code is only a
            // non-authorizing placeholder until the upload response is adopted.
            if (operation != "CREATE") put("employee_code",code)
        }.put("name",employee.nombre).put("phone",employee.telefono).put("email",employee.email).put("active",employee.isActive).put("updated_at",employee.updatedAt).toString()
        outbox.insert(EmployeeSyncOutboxEntity(employeeLocalId=employee.id,operation=operation,payloadJson=payload,idempotencyKey=key))
        Log.d("EMPLOYEE_OUTBOX","employeeId=${employee.id} remoteId=${employee.remoteId} code=${EmployeeCodePolicy.maskForLog(employee.employeeCode)} operation=$operation syncStatus=PENDING idempotencyKey=$key")
    }

    suspend fun enqueueFaceEmbedding(employee: Employee, embedding: FloatArray) {
        require(embedding.size == 128 && embedding.all { it.isFinite() })
        val outbox = outboxDao ?: return
        val code = requireNotNull(EmployeeCodePolicy.normalizeOrNull(employee.employeeCode)) {
            EmployeeCodePolicy.ERROR
        }
        val key = UUID.randomUUID().toString()
        val payload = JSONObject().put("idempotency_key", key).put("operation", "UPDATE")
            .put("local_employee_id", employee.id).put("remote_id", employee.remoteId)
            .put("employee_code", code).put("name", employee.nombre)
            .put("phone", employee.telefono).put("email", employee.email).put("active", employee.isActive)
            .put("updated_at", System.currentTimeMillis()).put("face_embedding", org.json.JSONArray(embedding.toList())).toString()
        val outboxId = outbox.insert(EmployeeSyncOutboxEntity(employeeLocalId = employee.id, operation = "UPDATE", payloadJson = payload, idempotencyKey = key))
        Log.d(
            "FACE_EMBEDDING_FLOW",
            "stage=outbox employeeId=${employee.id} outboxId=$outboxId operation=UPDATE faceEmbeddingType=array dimension=${embedding.size}"
        )
    }

    private companion object {
        val EMPLOYEE_CREATION_MUTEX = Mutex()
    }
}
