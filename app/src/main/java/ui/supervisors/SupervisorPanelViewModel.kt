package com.example.controlhorario.ui.supervisors

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.DepartmentEntity
import com.example.controlhorario.database.SupervisorEntity
import com.example.controlhorario.database.SupervisorEventEntity
import com.example.controlhorario.database.SupervisorWorkScheduleEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.DepartmentRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.SupervisorEventRepository
import com.example.controlhorario.repository.SupervisorRepository
import com.example.controlhorario.repository.SupervisorWorkScheduleRepository
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class SupervisorPanelViewModel(
    private val supervisorId: Int,
    private val supervisorRepository: SupervisorRepository,
    private val employeeRepository: EmployeeRepository,
    private val departmentRepository: DepartmentRepository,
    private val attendanceRepository: AttendanceRepository,
    private val scheduleRepository: SupervisorWorkScheduleRepository,
    private val eventRepository: SupervisorEventRepository
) : ViewModel() {

    private val _supervisor = MutableStateFlow<SupervisorEntity?>(null)
    val supervisor: StateFlow<SupervisorEntity?> = _supervisor.asStateFlow()

    private val _departmentIds = MutableStateFlow<List<Int>>(emptyList())
    val departmentIds: StateFlow<List<Int>> = _departmentIds.asStateFlow()

    private val _departments = MutableStateFlow<List<DepartmentEntity>>(emptyList())
    val departments: StateFlow<List<DepartmentEntity>> = _departments.asStateFlow()

    private val _employees = MutableStateFlow<List<Employee>>(emptyList())
    val employees: StateFlow<List<Employee>> = _employees.asStateFlow()

    private val _selectedEmployee = MutableStateFlow<Employee?>(null)
    val selectedEmployee: StateFlow<Employee?> = _selectedEmployee.asStateFlow()

    private val _selectedSchedule = MutableStateFlow<SupervisorWorkScheduleEntity?>(null)
    val selectedSchedule: StateFlow<SupervisorWorkScheduleEntity?> = _selectedSchedule.asStateFlow()

    private val _events = MutableStateFlow<List<SupervisorEventEntity>>(emptyList())
    val events: StateFlow<List<SupervisorEventEntity>> = _events.asStateFlow()

    private val _message = MutableStateFlow("")
    val message: StateFlow<String> = _message.asStateFlow()

    init {
        viewModelScope.launch { _departmentIds.value = supervisorRepository.getDepartmentIdsNow(supervisorId) }
        viewModelScope.launch { departmentRepository.getAllDepartments().collect { _departments.value = it } }
        viewModelScope.launch {
            supervisorRepository.getDepartmentIdsForSupervisor(supervisorId).collect { ids ->
                _departmentIds.value = ids
                employeeRepository.getEmployeesByDepartments(ids).collect { _employees.value = it }
            }
        }
        viewModelScope.launch { eventRepository.getEventsForSupervisor(supervisorId).collect { _events.value = it } }
    }

    fun findEmployeeByCode(code: String) {
        val cleanCode = code.filter { it.isDigit() }.padStart(5, '0')
        viewModelScope.launch {
            val employee = employeeRepository.findAnyByEmployeeCode(cleanCode)
            if (employee == null || !_departmentIds.value.contains(employee.departmentId)) {
                _selectedEmployee.value = null
                _selectedSchedule.value = null
                _message.value = "Empleado no encontrado o no pertenece a sus departamentos."
                return@launch
            }
            _selectedEmployee.value = employee
            _selectedSchedule.value = scheduleRepository.getByEmployeeId(employee.id)
            _message.value = "Empleado encontrado."
        }
    }

    fun saveSchedule(start: String, lunchOut: String, lunchIn: String, end: String) {
        val employee = _selectedEmployee.value
        if (employee == null) {
            _message.value = "Primero busque un empleado."
            return
        }
        if (listOf(start, lunchOut, lunchIn, end).any { it.isBlank() }) {
            _message.value = "Complete todas las horas."
            return
        }
        viewModelScope.launch {
            val previous = scheduleRepository.getByEmployeeId(employee.id)
            val schedule = SupervisorWorkScheduleEntity(
                id = previous?.id ?: 0,
                employeeId = employee.id,
                supervisorId = supervisorId,
                startTime = start,
                lunchOutTime = lunchOut,
                lunchInTime = lunchIn,
                endTime = end,
                createdAt = previous?.createdAt ?: System.currentTimeMillis(),
                updatedAt = System.currentTimeMillis()
            )
            scheduleRepository.save(schedule)
            _selectedSchedule.value = schedule
            _message.value = "Horario guardado correctamente."
        }
    }

    fun setJornadaEnabled(enabled: Boolean) {
        val employee = _selectedEmployee.value
        if (employee == null) {
            _message.value = "Primero busque un empleado."
            return
        }
        viewModelScope.launch {
            employeeRepository.setJornadaEnabled(employee.id, enabled)
            val refreshed = employee.copy(jornadaEnabled = enabled)
            _selectedEmployee.value = refreshed
            _message.value = if (enabled) "ADMIN-ON: registro de jornada habilitado." else "ADMIN-OFF: registro de jornada deshabilitado. Se generó incidencia interna."
            if (!enabled) {
                eventRepository.insert(
                    SupervisorEventEntity(
                        supervisorId = supervisorId,
                        employeeId = employee.id,
                        employeeName = employee.nombre,
                        departmentName = departmentName(employee.departmentId),
                        eventType = "REGISTRO_DESHABILITADO",
                        eventDate = today(),
                        detail = "Registro de jornada deshabilitado. Incidencia interna generada.",
                        minutes = 0,
                        severity = "ROJO",
                        notificationPending = true
                    )
                )
            }
        }
    }

    fun generateTodayEvents() {
        viewModelScope.launch {
            val today = today()
            eventRepository.clearCalculatedEvents(supervisorId, today)
            val records = attendanceRepository.getAttendanceByDate(today).first()
            val schedules = _employees.value.mapNotNull { employee ->
                scheduleRepository.getByEmployeeId(employee.id)?.let { employee to it }
            }
            schedules.forEach { (employee, schedule) ->
                generateEventsForEmployee(today, employee, schedule, records.filter { it.employeeId == employee.id })
            }
            _message.value = "Eventos actualizados."
        }
    }

    private suspend fun generateEventsForEmployee(
        date: String,
        employee: Employee,
        schedule: SupervisorWorkScheduleEntity,
        records: List<AttendanceEntity>
    ) {
        val entrada = records.firstOrNull { it.actionType.contains("INICI", true) || it.actionType.contains("ENTRADA", true) }
        val salidaAlmuerzo = records.firstOrNull { it.actionType.contains("PAUSA", true) || it.actionType.contains("ALMUERZO", true) }
        val llegadaAlmuerzo = records.firstOrNull { it.actionType.contains("REAN", true) || it.actionType.contains("REGRES", true) }
        val salida = records.firstOrNull { it.actionType.contains("FINAL", true) || it.actionType.contains("SALIDA", true) }

        if (entrada == null) {
            insertEvent(employee, date, "NO_INICIO_JORNADA", "No inició jornada", 0, "ROJO")
        } else {
            val late = minutesBetween(schedule.startTime, entrada.time)
            if (late > 0) insertEvent(employee, date, "LLEGO_TARDE", "Llegó tarde $late minutos", late, severity(late))
        }

        if (salidaAlmuerzo != null && llegadaAlmuerzo != null) {
            val expectedLunch = minutesBetween(schedule.lunchOutTime, schedule.lunchInTime)
            val realLunch = minutesBetween(salidaAlmuerzo.time, llegadaAlmuerzo.time)
            val excess = realLunch - expectedLunch
            if (excess > 0) insertEvent(employee, date, "EXCEDIO_ALMUERZO", "Excedió almuerzo $excess minutos", excess, severity(excess))
        }

        if (salida == null) {
            insertEvent(employee, date, "NO_FINALIZO_JORNADA", "No finalizó jornada", 0, "ROJO")
        } else {
            val early = minutesBetween(salida.time, schedule.endTime)
            if (early > 0) insertEvent(employee, date, "SALIO_ANTES", "Salió antes de tiempo $early minutos", early, severity(early))
        }
    }

    private suspend fun insertEvent(employee: Employee, date: String, type: String, detail: String, minutes: Int, severity: String) {
        eventRepository.insert(
            SupervisorEventEntity(
                supervisorId = supervisorId,
                employeeId = employee.id,
                employeeName = employee.nombre,
                departmentName = departmentName(employee.departmentId),
                eventType = type,
                eventDate = date,
                detail = detail,
                minutes = minutes,
                severity = severity
            )
        )
    }

    private fun departmentName(departmentId: Int): String =
        _departments.value.firstOrNull { it.id == departmentId }?.name ?: "Departamento"

    private fun severity(minutes: Int): String = when {
        minutes <= 5 -> "VERDE"
        minutes <= 15 -> "AMARILLO"
        else -> "ROJO"
    }

    private fun minutesBetween(start: String, end: String): Int {
        return try {
            val format = SimpleDateFormat("HH:mm", Locale.getDefault())
            val startDate = format.parse(start) ?: return 0
            val endDate = format.parse(end) ?: return 0
            ((endDate.time - startDate.time) / 60000L).toInt()
        } catch (_: Exception) {
            0
        }
    }

    private fun today(): String = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
}

class SupervisorPanelViewModelFactory(
    private val supervisorId: Int,
    private val supervisorRepository: SupervisorRepository,
    private val employeeRepository: EmployeeRepository,
    private val departmentRepository: DepartmentRepository,
    private val attendanceRepository: AttendanceRepository,
    private val scheduleRepository: SupervisorWorkScheduleRepository,
    private val eventRepository: SupervisorEventRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return SupervisorPanelViewModel(
            supervisorId,
            supervisorRepository,
            employeeRepository,
            departmentRepository,
            attendanceRepository,
            scheduleRepository,
            eventRepository
        ) as T
    }
}
