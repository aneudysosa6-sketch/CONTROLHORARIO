package com.example.controlhorario.ui.permissions

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.SupervisorPermissionEntity
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun PermissionsScreen(
    viewModel: PermissionsViewModel,
    onBack: () -> Unit
) {
    val permissions by viewModel.permissions.collectAsState()
    var supervisorName by remember { mutableStateOf("") }
    var employeeName by remember { mutableStateOf("") }

    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Text("Permisos de Supervisores", style = MaterialTheme.typography.headlineSmall)
        Text("Asigna empleados a supervisores para operaciones futuras.")
        Spacer(Modifier.height(16.dp))
        OSINETTextField(supervisorName, { supervisorName = it }, "Supervisor", Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OSINETTextField(employeeName, { employeeName = it }, "Empleado", Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        OSINETButton(
            text = "Guardar permiso básico",
            onClick = {
                viewModel.save(
                    SupervisorPermissionEntity(
                        supervisorUserId = 0,
                        supervisorName = supervisorName,
                        employeeId = 0,
                        employeeName = employeeName,
                        createdAt = System.currentTimeMillis().toString()
                    )
                )
            }
        )
        Spacer(Modifier.height(8.dp))
        OSINETButton("Volver", onBack)
        Spacer(Modifier.height(16.dp))
        Text("Permisos registrados: ${permissions.size}")
    }
}
