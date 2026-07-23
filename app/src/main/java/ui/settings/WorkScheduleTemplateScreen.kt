package com.example.controlhorario.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Checkbox
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.SupervisorWorkScheduleEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.session.UserSessionManager
import com.example.controlhorario.model.WorkScheduleTemplate
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun WorkScheduleTemplateScreen(
    viewModel: WorkScheduleTemplateViewModel,
    employees: List<Employee>,
    assignedSchedules: List<SupervisorWorkScheduleEntity>,
    onBack: () -> Unit
) {
    val templates by viewModel.templates.collectAsState()
    val currentUser by UserSessionManager.currentUser.collectAsState()

    var nombre by remember { mutableStateOf("") }
    var descripcion by remember { mutableStateOf("") }
    var horaEntrada by remember { mutableStateOf("") }
    var horaSalida by remember { mutableStateOf("") }
    var almuerzo by remember { mutableStateOf("2") }
    var jornadaMaxima by remember { mutableStateOf("12") }
    var horarioFlexible by remember { mutableStateOf(false) }

    var lunes by remember { mutableStateOf(true) }
    var martes by remember { mutableStateOf(true) }
    var miercoles by remember { mutableStateOf(true) }
    var jueves by remember { mutableStateOf(true) }
    var viernes by remember { mutableStateOf(true) }
    var sabado by remember { mutableStateOf(false) }
    var domingo by remember { mutableStateOf(false) }

    var mensaje by remember { mutableStateOf("") }
    var teamOnly by remember { mutableStateOf(false) }
    val hasTeamScope = (currentUser?.departmentId ?: 0) > 0 || (currentUser?.branchId ?: 0) > 0
    val employeeById = employees.associateBy(Employee::id)
    val visibleAssignedSchedules = assignedSchedules.filter { schedule ->
        !teamOnly || employeeById[schedule.employeeId]?.let { employee ->
            when {
                (currentUser?.departmentId ?: 0) > 0 -> employee.departmentId == currentUser?.departmentId
                (currentUser?.branchId ?: 0) > 0 -> employee.branchId == currentUser?.branchId
                else -> false
            }
        } == true
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {
        item {
            Text(text = "Horarios", style = MaterialTheme.typography.headlineMedium)

            Spacer(modifier = Modifier.height(12.dp))

            Text("Horarios asignados", style = MaterialTheme.typography.titleMedium)
            Spacer(modifier = Modifier.height(8.dp))
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(
                    onClick = { teamOnly = false },
                    modifier = Modifier.weight(1f),
                    enabled = teamOnly,
                ) { Text("Todos") }
                OutlinedButton(
                    onClick = { teamOnly = true },
                    modifier = Modifier.weight(1f),
                    enabled = !teamOnly,
                ) { Text("Solo mi equipo") }
            }
            if (teamOnly && !hasTeamScope) {
                Spacer(modifier = Modifier.height(8.dp))
                Text("No tienes un departamento o sucursal asignados para filtrar tu equipo.")
            }
            Spacer(modifier = Modifier.height(8.dp))
            if (visibleAssignedSchedules.isEmpty()) {
                Text(if (teamOnly) "No hay horarios asignados a tu equipo." else "No hay horarios de empleados asignados.")
            } else {
                visibleAssignedSchedules.forEach { schedule ->
                    val employee = employeeById[schedule.employeeId]
                    Text(employee?.nombre ?: "Empleado ${schedule.employeeId}")
                    Text("${schedule.startTime} - ${schedule.endTime} · Almuerzo ${schedule.lunchOutTime} - ${schedule.lunchInTime}")
                    Spacer(modifier = Modifier.height(8.dp))
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "Plantillas de jornada",
                style = MaterialTheme.typography.titleMedium
            )

            Spacer(modifier = Modifier.height(16.dp))

            OSINETTextField(nombre, { nombre = it }, "Nombre de plantilla", Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(10.dp))

            OSINETTextField(descripcion, { descripcion = it }, "Descripción", Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(10.dp))

            OSINETTextField(horaEntrada, { horaEntrada = it }, "Hora entrada ej: 08:00", Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(10.dp))

            OSINETTextField(horaSalida, { horaSalida = it }, "Hora salida ej: 17:00", Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(10.dp))

            OSINETTextField(almuerzo, { almuerzo = it }, "Tiempo almuerzo horas", Modifier.fillMaxWidth())
            Spacer(modifier = Modifier.height(10.dp))

            OSINETTextField(jornadaMaxima, { jornadaMaxima = it }, "Jornada máxima horas", Modifier.fillMaxWidth())

            Spacer(modifier = Modifier.height(16.dp))

            Text("Días laborales", style = MaterialTheme.typography.titleMedium)

            DayCheck("Lunes", lunes) { lunes = it }
            DayCheck("Martes", martes) { martes = it }
            DayCheck("Miércoles", miercoles) { miercoles = it }
            DayCheck("Jueves", jueves) { jueves = it }
            DayCheck("Viernes", viernes) { viernes = it }
            DayCheck("Sábado", sabado) { sabado = it }
            DayCheck("Domingo", domingo) { domingo = it }

            DayCheck("Horario flexible", horarioFlexible) { horarioFlexible = it }

            Spacer(modifier = Modifier.height(12.dp))

            if (mensaje.isNotEmpty()) {
                Text(mensaje)
                Spacer(modifier = Modifier.height(12.dp))
            }

            OSINETButton(
                text = "💾 Guardar plantilla",
                onClick = {
                    val template = WorkScheduleTemplate(
                        nombre = nombre,
                        descripcion = descripcion,
                        lunes = lunes,
                        martes = martes,
                        miercoles = miercoles,
                        jueves = jueves,
                        viernes = viernes,
                        sabado = sabado,
                        domingo = domingo,
                        horaEntrada = horaEntrada,
                        horaSalida = horaSalida,
                        tiempoAlmuerzoHoras = almuerzo.toDoubleOrNull() ?: 2.0,
                        jornadaMaximaHoras = jornadaMaxima.toDoubleOrNull() ?: 12.0,
                        horarioFlexible = horarioFlexible
                    )

                    viewModel.addTemplate(template)

                    nombre = ""
                    descripcion = ""
                    horaEntrada = ""
                    horaSalida = ""
                    almuerzo = "2"
                    jornadaMaxima = "12"
                    mensaje = "Plantilla guardada correctamente ✅"
                }
            )

            Spacer(modifier = Modifier.height(20.dp))

            Text("Plantillas guardadas", style = MaterialTheme.typography.titleMedium)

            Spacer(modifier = Modifier.height(12.dp))
        }

        items(templates) { template ->
            Text("🕒 ${template.nombre}")
            Text("Entrada: ${template.horaEntrada} | Salida: ${template.horaSalida}")
            Text("Almuerzo: ${template.tiempoAlmuerzoHoras} h | Máx: ${template.jornadaMaximaHoras} h")
            Text("Flexible: ${if (template.horarioFlexible) "Sí" else "No"}")
            Spacer(modifier = Modifier.height(14.dp))
        }

        item {
            Spacer(modifier = Modifier.height(20.dp))

            OutlinedButton(
                onClick = onBack,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("⬅ Volver")
            }
        }
    }
}

@Composable
fun DayCheck(
    text: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text)
        Checkbox(
            checked = checked,
            onCheckedChange = onCheckedChange
        )
    }
}
