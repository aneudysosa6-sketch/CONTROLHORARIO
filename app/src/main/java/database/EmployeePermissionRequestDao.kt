package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EmployeePermissionRequestDao {
    @Query("SELECT * FROM employee_permission_requests WHERE isActive=1 ORDER BY id DESC")
    fun getAllRequests():Flow<List<EmployeePermissionRequestEntity>>
    @Query("SELECT * FROM employee_permission_requests WHERE employeeId=:employeeId AND isActive=1 ORDER BY id DESC")
    fun getRequestsByEmployee(employeeId:Int):Flow<List<EmployeePermissionRequestEntity>>
    @Insert(onConflict=OnConflictStrategy.REPLACE)
    suspend fun saveRequest(request:EmployeePermissionRequestEntity):Long

    @Query("""UPDATE employee_permission_requests SET status=:status,reviewedBy=:reviewedBy,
        reviewedDate=:reviewedDate,rejectionReason='',licenseStartDate=:licenseStartDate,
        licenseEndDate=:licenseEndDate,licensePayPercent=:licensePayPercent,
        normalDailyAmount=:normalDailyAmount,licenseDailyAmount=:licenseDailyAmount,
        licenseTotalAmount=:licenseTotalAmount,updatedAt=:updatedAt
        WHERE id=:requestId AND status='PENDIENTE' AND isActive=1""")
    suspend fun approveRequest(requestId:Int,status:String,reviewedBy:String,reviewedDate:String,
        licenseStartDate:String,licenseEndDate:String,licensePayPercent:Double,
        normalDailyAmount:Double,licenseDailyAmount:Double,licenseTotalAmount:Double,updatedAt:String):Int

    @Query("""UPDATE employee_permission_requests SET status=:status,reviewedBy=:reviewedBy,
        reviewedDate=:reviewedDate,rejectionReason=:rejectionReason,updatedAt=:updatedAt
        WHERE id=:requestId AND status='PENDIENTE' AND isActive=1
        AND length(trim(:rejectionReason))>0""")
    suspend fun rejectRequest(requestId:Int,status:String,reviewedBy:String,reviewedDate:String,rejectionReason:String,updatedAt:String):Int

    @Query("""UPDATE employee_permission_requests SET status=:status,reviewedBy=:actor,
        reviewedDate=:changedAt,rejectionReason='',licenseStartDate=:licenseStartDate,
        licenseEndDate=:licenseEndDate,licensePayPercent=:licensePayPercent,
        normalDailyAmount=:normalDailyAmount,licenseDailyAmount=:licenseDailyAmount,
        licenseTotalAmount=:licenseTotalAmount,updatedAt=:updatedAt
        WHERE id=:requestId AND requestType='LICENCIA_MEDICA' AND status='PENDIENTE' AND isActive=1""")
    suspend fun activateDirectLicense(requestId:Int,status:String,actor:String,changedAt:String,
        licenseStartDate:String,licenseEndDate:String,licensePayPercent:Double,
        normalDailyAmount:Double,licenseDailyAmount:Double,licenseTotalAmount:Double,updatedAt:String):Int

    @Query("""UPDATE employee_permission_requests SET reviewedBy=:actor,reviewedDate=:changedAt,
        licenseStartDate=:licenseStartDate,licenseEndDate=:licenseEndDate,
        licensePayPercent=:licensePayPercent,normalDailyAmount=:normalDailyAmount,
        licenseDailyAmount=:licenseDailyAmount,licenseTotalAmount=:licenseTotalAmount,updatedAt=:updatedAt
        WHERE id=:requestId AND requestType='LICENCIA_MEDICA' AND status='ACTIVA' AND isActive=1""")
    suspend fun editDirectLicense(requestId:Int,actor:String,changedAt:String,
        licenseStartDate:String,licenseEndDate:String,licensePayPercent:Double,
        normalDailyAmount:Double,licenseDailyAmount:Double,licenseTotalAmount:Double,updatedAt:String):Int

    @Query("""UPDATE employee_permission_requests SET status=:status,reviewedBy=:actor,
        reviewedDate=:changedAt,rejectionReason=:reason,updatedAt=:updatedAt
        WHERE id=:requestId AND requestType='LICENCIA_MEDICA' AND status='ACTIVA' AND isActive=1
        AND length(trim(:reason))>0""")
    suspend fun cancelDirectLicense(requestId:Int,status:String,actor:String,changedAt:String,reason:String,updatedAt:String):Int
}