package com.example.controlhorario.repository

import com.example.controlhorario.database.JourneyDao
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.ui.punch.JourneyBiometricProof

class JourneyRepository(private val dao:JourneyDao){
 fun observe(employeeId:Int,workDate:String)=dao.observe(employeeId,workDate)
 fun observeAll()=dao.observeAll()
 suspend fun recordAction(employeeLocalId:Int,employeeRemoteId:String,employeeCode:String,employeeName:String,deviceId:String,branchId:String?,departmentId:String?,workDate:String,occurredAt:String,action:JourneyAction,jornadaEnabled:Boolean,proof:JourneyBiometricProof,proofSignature:String)=dao.recordAction(employeeLocalId,employeeRemoteId,employeeCode,employeeName,deviceId,branchId,departmentId,workDate,occurredAt,action,jornadaEnabled,proof,proofSignature)
}
