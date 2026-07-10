package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface AttendanceDao {

    @Query("SELECT * FROM attendance_records ORDER BY date DESC, time DESC")
    fun getAllAttendanceRecords(): Flow<List<AttendanceEntity>>

    @Query("SELECT * FROM attendance_records WHERE employeeId = :employeeId ORDER BY date DESC, time DESC")
    fun getAttendanceByEmployee(employeeId: Int): Flow<List<AttendanceEntity>>

    @Query("SELECT * FROM attendance_records WHERE date = :date ORDER BY time DESC")
    fun getAttendanceByDate(date: String): Flow<List<AttendanceEntity>>

    @Insert
    suspend fun insertAttendance(record: AttendanceEntity)
}