package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeDao
import com.example.controlhorario.database.JourneyDao
import com.example.controlhorario.database.LocalJourneyResult
import com.example.controlhorario.attendance.JourneyCurrentStateSynchronizer
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.model.EmployeeEmploymentPolicy
import com.example.controlhorario.ui.punch.JourneyBiometricProof

enum class JourneyCurrentStateOutcome { REMOTE_SUCCESS, REMOTE_EMPTY, LOCAL_CACHE, LOCAL_PENDING, NETWORK_ERROR, CONFLICT }
data class JourneyCurrentStateRefreshResult(
 val workDate:String,
 val remoteExists:Boolean,
 val remoteVersion:Long?,
 val finalResult:JourneyCurrentStateOutcome
)
class JourneyCurrentStateSyncException(
 val code:String,
 val outcome:JourneyCurrentStateOutcome,
 cause:Throwable?=null
):Exception(code,cause)

class JourneyRepository(
 private val dao:JourneyDao,
 private val employeeDao:EmployeeDao,
 private val currentStateSynchronizer:JourneyCurrentStateSynchronizer?=null
){
 fun observe(employeeId:Int,workDate:String)=dao.observe(employeeId,workDate)
 fun observeAll()=dao.observeAll()
 suspend fun refreshCurrentState(employeeLocalId:Int,requestedAt:String):JourneyCurrentStateRefreshResult=
  currentStateSynchronizer?.refresh(employeeLocalId,requestedAt)
   ?:throw JourneyCurrentStateSyncException("CURRENT_STATE_SYNC_NOT_CONFIGURED",JourneyCurrentStateOutcome.NETWORK_ERROR)
 suspend fun recordAction(employeeLocalId:Int,employeeRemoteId:String,employeeCode:String,employeeName:String,deviceId:String,branchId:String?,departmentId:String?,workDate:String,occurredAt:String,action:JourneyAction,jornadaEnabled:Boolean,proof:JourneyBiometricProof,proofSignature:String):LocalJourneyResult {
  val current=employeeDao.findByLocalId(employeeLocalId)
  check(current!=null&&current.remoteId==employeeRemoteId&&EmployeeEmploymentPolicy.canRegisterAttendance(current)){"EMPLOYEE_INACTIVE"}
  return dao.recordAction(employeeLocalId,employeeRemoteId,employeeCode,employeeName,deviceId,branchId,departmentId,workDate,occurredAt,action,jornadaEnabled&&current.jornadaEnabled,proof,proofSignature)
 }
}
