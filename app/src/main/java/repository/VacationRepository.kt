package com.example.controlhorario.repository

import com.example.controlhorario.database.VacationDao
import com.example.controlhorario.database.VacationEntity
import com.example.controlhorario.engine.VacationLifecyclePolicy
import kotlinx.coroutines.flow.Flow

class VacationRepository(private val vacationDao:VacationDao) {
    fun getAllVacations():Flow<List<VacationEntity>> = vacationDao.getAllVacations()
    fun getVacationsByEmployee(employeeId:Int)=vacationDao.getVacationsByEmployee(employeeId)
    fun getVacationsByStatus(status:String)=vacationDao.getVacationsByStatus(status)
    fun getVacationById(vacationId:Int)=vacationDao.getVacationById(vacationId)
    suspend fun saveVacation(vacation:VacationEntity):Boolean {
        if(vacation.requestedDays<=0||!VacationLifecyclePolicy.hasValidRange(vacation.startDate,vacation.endDate))return false
        vacationDao.saveVacation(vacation)
        return true
    }
    suspend fun approveVacation(vacationId:Int,approvedBy:String,approvedDate:String,approvedDays:Int,remainingDays:Int,updatedAt:String):Boolean {
        if(approvedDays<=0||remainingDays<0)return false
        return vacationDao.approveVacation(vacationId,VacationEntity.STATUS_APPROVED,approvedBy,approvedDate,approvedDays,remainingDays,updatedAt)==1
    }
    suspend fun rejectVacation(vacationId:Int,rejectedBy:String,rejectedDate:String,rejectionReason:String,updatedAt:String):Boolean {
        if(rejectionReason.isBlank())return false
        return vacationDao.rejectVacation(vacationId,VacationEntity.STATUS_REJECTED,rejectedBy,rejectedDate,rejectionReason,updatedAt)==1
    }
    suspend fun cancelVacation(vacationId:Int,updatedAt:String):Boolean =
        vacationDao.cancelVacation(vacationId,VacationEntity.STATUS_CANCELLED,updatedAt)==1
    suspend fun deactivateVacation(vacationId:Int,updatedAt:String){vacationDao.deactivateVacation(vacationId,updatedAt)}
}