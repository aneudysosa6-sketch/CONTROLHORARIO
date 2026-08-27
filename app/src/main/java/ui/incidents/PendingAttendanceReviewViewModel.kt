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
    private val attendanceRepository: AttendanceRepository,
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
        viewModelScope.launch { reviewRepository.getAll().collect { _reviews.value = it } }
        viewModelScope.launch { attendanceRepository.getAllAttendanceRecords().collect { _attendanceRecords.value = it } }
    }

    fun setDashboardDate(date: String) { _dashboardDate.value = date }

    fun finishOpenShift(employeeId: Int, employeeName: String) {
        _message.value = "La jornada incompleta de $employeeName debe resolverse con NO PAGAR o evidencia demostrable."
    }

    fun runClosureForYesterday() = runClosureForDate(yesterday())
    fun runClosureForToday() = runClosureForDate(today())

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
                        records = records.filter { it.employeeId == employee.id },
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

    fun resolveNoPay(review: PendingAttendanceReviewEntity) {
        viewModelScope.launch {
            reviewRepository.resolveNoPay(review.id, "NO PAGAR: resolución administrativa auditable")
            _message.value = "Jornada resuelta como NO PAGAR."
        }
    }

    fun resolveDemonstrable(review: PendingAttendanceReviewEntity, manualHours: Double?) {
        val onlyStart = review.checkInTime.isNotBlank() &&
            review.lunchOutTime.isBlank() && review.lunchInTime.isBlank() && review.checkOutTime.isBlank()
        val hours = if (onlyStart) manualHours else review.calculatedHours
        if (onlyStart && (hours == null || hours !in 0.0..8.0)) {
            _message.value = "Con solo entrada, indique entre 0 y 8 horas."
            return
        }
        if (!onlyStart && manualHours != null) {
            _message.value = "Las horas manuales solo aplican cuando existe únicamente la entrada."
            return
        }
        viewModelScope.launch {
            reviewRepository.resolveDemonstrable(
                review.id,
                requireNotNull(hours).coerceAtLeast(0.0),
                if (onlyStart) "Horas manuales por única marca INICIAR" else "Intervalos cerrados demostrables",
            )
            _message.value = "Jornada incompleta resuelta con evidencia demostrable."
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
}

class PendingAttendanceReviewViewModelFactory(
    private val reviewRepository: PendingAttendanceReviewRepository,
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        PendingAttendanceReviewViewModel(reviewRepository, employeeRepository, attendanceRepository) as T
}
