package com.example.controlhorario.ui.attendance

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.repository.AttendanceRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class AttendanceViewModel(
    private val repository: AttendanceRepository
) : ViewModel() {

    val attendanceRecords: StateFlow<List<AttendanceEntity>> =
        repository.getAllAttendanceRecords()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    fun registerAttendance(
        employeeId: Int,
        employeeName: String,
        date: String,
        time: String,
        actionType: String,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        biometricVerified: Boolean = false,
        deviceName: String = "",
        notes: String = ""
    ) {
        registerAttendanceAndThen(
            employeeId = employeeId,
            employeeName = employeeName,
            date = date,
            time = time,
            actionType = actionType,
            latitude = latitude,
            longitude = longitude,
            biometricVerified = biometricVerified,
            deviceName = deviceName,
            notes = notes
        )
    }

    fun registerAttendanceAndThen(
        employeeId: Int,
        employeeName: String,
        date: String,
        time: String,
        actionType: String,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        biometricVerified: Boolean = false,
        deviceName: String = "",
        notes: String = "",
        onSaved: () -> Unit = {}
    ) {
        viewModelScope.launch {
            repository.insertAttendance(
                AttendanceEntity(
                    employeeId = employeeId,
                    employeeName = employeeName,
                    date = date,
                    time = time,
                    actionType = actionType,
                    latitude = latitude,
                    longitude = longitude,
                    biometricVerified = biometricVerified,
                    deviceName = deviceName,
                    notes = notes
                )
            )
            onSaved()
        }
    }

}