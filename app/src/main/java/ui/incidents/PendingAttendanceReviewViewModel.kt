package com.example.controlhorario.ui.incidents

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.PendingAttendanceReviewEntity
import com.example.controlhorario.engine.AttendanceAction
import com.example.controlhorario.engine.PendingAttendanceReviewEngine
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.PendingAttendanceReviewRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class PendingAttendanceReviewViewModel(
    private val reviewRepository: PendingAttendanceReviewRepository,
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository
) : ViewModel() {

    private val _reviews = MutableStateFlow<List<PendingAttendanceReviewEntity>>(emptyList())
    val reviews: StateFlow<List<PendingAttendanceReviewEntity>> = _reviews.asStateFlow()

    private val _message = MutableStateFlow("")
    val message: StateFlow<String> = _message.asStateFlow()

    private val _dashboardDate = MutableStateFlow(today())
    val dashboardDate: StateFlow<String> = _dashboardDate.asStateFlow()

    private val _attendanceRecords = MutableStateFlow<List<AttendanceEntity>>(emptyList())
    val attendanceRecords: StateFlow<List<AttendanceEntity>> = _attendanceRecords.asStateFlow()

    init {
        viewModelScope.launch {
            reviewRepository.getAll().collect { _reviews.value = it }
        }
        viewModelScope.launch {
            attendanceRepository.getAllAttendanceRecords().collect { _attendanceRecords.value = it }
        }
    }

    fun setDashboardDate(date: String) {
        _dashboardDate.value = date
    }

    fun finishOpenShift(employeeId: Int, employeeName: String) {
        viewModelScope.launch {
            val now = Date()
            attendanceRepository.insertAttendance(
                AttendanceEntity(
                    employeeId = employeeId,
                    employeeName = employeeName,
                    date = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(now),
                    time = SimpleDateFormat("HH:mm:ss", Locale.getDefault()).format(now),
                    actionType = AttendanceAction.FIN_JORNADA.name,
                    biometricVerified = false,
                    deviceName = "Centro de Incidencias",
                    notes = "Jornada finalizada manualmente desde Centro de Incidencias"
                )
            )
            _message.value = "Jornada finalizada para $employeeName. Esta salida será tomada en cuenta por nómina."
        }
    }

    fun runClosureForYesterday() {
        val date = yesterday()
        runClosureForDate(date)
    }

    fun runClosureForToday() {
        val date = today()
        runClosureForDate(date)
    }

    private fun runClosureForDate(date: String) {
        viewModelScope.launch {
            val employees = employeeRepository.getAllEmployees().first()
            val records = attendanceRepository.getAttendanceByDate(date).first()
            var created = 0
            employees.forEach { employee: Employee ->
                val current = reviewRepository.findPendingForEmployeeDate(employee.id, date)
                if (current == null) {
                    val pending = PendingAttendanceReviewEngine.buildIfIncomplete(
                        employee = employee,
                        date = date,
                        records = records.filter { it.employeeId == employee.id }
                    )
                    if (pending != null) {
                        val id = reviewRepository.save(pending)
                        registerInternalNotification(pending.copy(id = id.toInt()))
                        created++
                    }
                }
            }
            _message.value = "Cierre ejecutado para $date. Jornadas pendientes creadas: $created."
        }
    }

    fun approve(review: PendingAttendanceReviewEntity) {
        viewModelScope.launch {
            reviewRepository.approve(review.id, "Aprobada por administrador")
            _message.value = "Jornada aprobada."
        }
    }

    fun reject(review: PendingAttendanceReviewEntity) {
        viewModelScope.launch {
            reviewRepository.reject(review.id, "Rechazada por administrador")
            _message.value = "Jornada rechazada."
        }
    }

    fun markEdited(review: PendingAttendanceReviewEntity) {
        viewModelScope.launch {
            reviewRepository.markEditedApproved(review.id, "Editada y aprobada por administrador")
            _message.value = "Jornada marcada como editada/aprobada."
        }
    }

    private fun registerInternalNotification(review: PendingAttendanceReviewEntity) {
        _message.value = "Incidencia creada para ${review.employeeName}: ${review.severity} - ${review.reason}"
    }

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

    private fun yesterday(): String {
        val calendar = Calendar.getInstance()
        calendar.add(Calendar.DAY_OF_YEAR, -1)
        return SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(calendar.time)
    }

    private fun nowDateTime(): String = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault()).format(Date())
}

class PendingAttendanceReviewViewModelFactory(
    private val reviewRepository: PendingAttendanceReviewRepository,
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return PendingAttendanceReviewViewModel(
            reviewRepository,
            employeeRepository,
            attendanceRepository
        ) as T
    }
}
