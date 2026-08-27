package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface VacationDao {
    @Query("SELECT * FROM vacations WHERE isActive=1 ORDER BY id DESC")
    fun getAllVacations():Flow<List<VacationEntity>>
    @Query("SELECT * FROM vacations WHERE employeeId=:employeeId AND isActive=1 ORDER BY id DESC")
    fun getVacationsByEmployee(employeeId:Int):Flow<List<VacationEntity>>
    @Query("SELECT * FROM vacations WHERE status=:status AND isActive=1 ORDER BY id DESC")
    fun getVacationsByStatus(status:String):Flow<List<VacationEntity>>
    @Query("SELECT * FROM vacations WHERE id=:vacationId LIMIT 1")
    fun getVacationById(vacationId:Int):Flow<VacationEntity?>
    @Insert(onConflict=OnConflictStrategy.REPLACE)
    suspend fun saveVacation(vacation:VacationEntity)

    @Query("""UPDATE vacations SET status=:status,approvedBy=:approvedBy,approvedDate=:approvedDate,
        approvedDays=:approvedDays,remainingDays=:remainingDays,updatedAt=:updatedAt
        WHERE id=:vacationId AND status='PENDIENTE' AND isActive=1
        AND :approvedDays>0 AND :approvedDays<=requestedDays AND :remainingDays>=0""")
    suspend fun approveVacation(vacationId:Int,status:String,approvedBy:String,approvedDate:String,approvedDays:Int,remainingDays:Int,updatedAt:String):Int

    @Query("""UPDATE vacations SET status=:status,rejectedBy=:rejectedBy,rejectedDate=:rejectedDate,
        rejectionReason=:rejectionReason,updatedAt=:updatedAt
        WHERE id=:vacationId AND status='PENDIENTE' AND isActive=1 AND length(trim(:rejectionReason))>0""")
    suspend fun rejectVacation(vacationId:Int,status:String,rejectedBy:String,rejectedDate:String,rejectionReason:String,updatedAt:String):Int

    @Query("UPDATE vacations SET status=:status,updatedAt=:updatedAt WHERE id=:vacationId AND status='PENDIENTE' AND isActive=1")
    suspend fun cancelVacation(vacationId:Int,status:String,updatedAt:String):Int
    @Query("UPDATE vacations SET isActive=0,updatedAt=:updatedAt WHERE id=:vacationId")
    suspend fun deactivateVacation(vacationId:Int,updatedAt:String)
}