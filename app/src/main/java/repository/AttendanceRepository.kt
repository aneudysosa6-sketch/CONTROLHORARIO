package com.example.controlhorario.repository

import com.example.controlhorario.database.AttendanceDao
import com.example.controlhorario.database.AttendanceEntity
import kotlinx.coroutines.flow.Flow

class AttendanceRepository(
    private val dao: AttendanceDao
) {

    fun getAllAttendanceRecords(): Flow<List<AttendanceEntity>> {
        return dao.getAllAttendanceRecords()
    }

    fun getAttendanceByEmployee(employeeId: Int): Flow<List<AttendanceEntity>> {
        return dao.getAttendanceByEmployee(employeeId)
    }

    fun getAttendanceByDate(date: String): Flow<List<AttendanceEntity>> {
        return dao.getAttendanceByDate(date)
    }

    suspend fun insertAttendance(record: AttendanceEntity) {
        dao.insertAttendance(record)
    }
}