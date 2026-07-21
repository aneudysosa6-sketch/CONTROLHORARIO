package com.example.controlhorario.ui.supervisors

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.SupervisorEntity
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun SupervisorAdminScreen(
    viewModel: SupervisorAdminViewModel,
    onBack: () -> Unit
) {
    val supervisors by viewModel.supervisors.collectAsState()
    val branches by viewModel.branches.collectAsState()
    val departments by viewModel.departments.collectAsState()
    val selectedDepartmentIds by viewModel.selectedDepartmentIds.collectAsState()
    val message by viewModel.message.collectAsState()

    var editingId by remember { mutableIntStateOf(0) }
    var fullName by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var active by remember { mutableStateOf(true) }

    fun loadSupervisor(supervisor: SupervisorEntity) {
        editingId = supervisor.id
        fullName = supervisor.fullName
        username = supervisor.username
        password = supervisor.password
        active = supervisor.isActive
        viewModel.loadDepartmentsForSupervisor(supervisor.id)
    }

    fun clearForm() {
        editingId = 0
        fullName = ""
        username = ""
        password = ""
        active = true
        viewModel.clearSelection()
    }

    Scaffold { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text("SUPERVISORES", style = MaterialTheme.typography.headlineMedium)
            Text("Crear accesos de supervisores y asignar departamentos. No se asignan sucursales directamente.")

            ElevatedCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    Text(if (editingId == 0) "Crear supervisor" else "Editar supervisor", style = MaterialTheme.typography.titleMedium)
                    OSINETTextField(value = fullName, onValueChange = { fullName = it }, label = "Nombre completo", modifier = Modifier.fillMaxWidth())
                    OSINETTextField(value = username, onValueChange = { username = it }, label = "Usuario", modifier = Modifier.fillMaxWidth())
                    OSINETTextField(value = password, onValueChange = { password = it }, label = "Contraseña", modifier = Modifier.fillMaxWidth(), visualTransformation = PasswordVisualTransformation())
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(checked = active, onCheckedChange = { active = it })
                        Text("Supervisor activo")
                    }
                    Text("Departamentos asignados", style = MaterialTheme.typography.titleSmall)
                    branches.forEach { branch ->
                        val branchDepartments = departments.filter { it.branchId == branch.id }
                        if (branchDepartments.isNotEmpty()) {
                            Text("Sucursal: ${branch.name}", style = MaterialTheme.typography.labelLarge)
                            branchDepartments.forEach { department ->
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Checkbox(
                                        checked = selectedDepartmentIds.contains(department.id),
                                        onCheckedChange = { viewModel.toggleDepartment(department.id) }
                                    )
                                    Text("${department.name} (${department.code})")
                                }
                            }
                        }
                    }
                    if (message.isNotBlank()) Text(message)
                    OSINETButton(
                        text = if (editingId == 0) "Guardar supervisor" else "Actualizar supervisor",
                        onClick = { viewModel.saveSupervisor(editingId, fullName, username, password, active) }
                    )
                    OutlinedButton(modifier = Modifier.fillMaxWidth(), onClick = { clearForm() }) { Text("Nuevo / limpiar") }
                }
            }

            Text("Supervisores creados", style = MaterialTheme.typography.titleMedium)
            supervisors.forEach { supervisor ->
                ElevatedCard(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        Text(supervisor.fullName, style = MaterialTheme.typography.titleSmall)
                        Text("Usuario: ${supervisor.username}")
                        Text(if (supervisor.isActive) "Estado: Activo" else "Estado: Inactivo")
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { loadSupervisor(supervisor) }) { Text("Editar") }
                            OutlinedButton(onClick = { viewModel.setActive(supervisor.id, !supervisor.isActive) }) {
                                Text(if (supervisor.isActive) "Inactivar" else "Activar")
                            }
                        }
                    }
                }
            }

            Spacer(Modifier.height(8.dp))
            OutlinedButton(modifier = Modifier.fillMaxWidth(), onClick = onBack) { Text("Volver") }
        }
    }
}
