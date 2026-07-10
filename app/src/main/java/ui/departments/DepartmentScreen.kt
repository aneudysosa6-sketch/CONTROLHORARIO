package com.example.controlhorario.ui.departments

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.ui.components.OSINETTextField

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DepartmentScreen(
    branches: List<BranchEntity>,
    users: List<AppUserEntity>,
    viewModel: DepartmentViewModel,
    onBack: () -> Unit
) {
    val departments by viewModel.departments.collectAsState()

    var selectedBranch by remember { mutableStateOf<BranchEntity?>(null) }
    var expanded by remember { mutableStateOf(false) }

    var name by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var manager by remember { mutableStateOf("") }
    var managerExpanded by remember { mutableStateOf(false) }
    val branchManagers = users.filter { it.role == "ENCARGADO" && it.branchId == selectedBranch?.id && it.isActive }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Departamentos") }
            )
        }
    ) { padding ->

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {

            item {
                Text("Sucursal")

                Spacer(modifier = Modifier.height(8.dp))

                OutlinedButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = { expanded = true }
                ) {
                    Text(selectedBranch?.name ?: "Seleccionar sucursal")
                }

                DropdownMenu(
                    expanded = expanded,
                    onDismissRequest = { expanded = false }
                ) {
                    branches.forEach { branch ->
                        DropdownMenuItem(
                            text = {
                                Text("${branch.name} - ${branch.city}")
                            },
                            onClick = {
                                selectedBranch = branch
                                expanded = false
                            }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                OSINETTextField(name, { name = it }, "Nombre del departamento", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(code, { code = it }, "Código", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(description, { description = it }, "Descripción", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                Text("Encargado")
                Spacer(modifier = Modifier.height(8.dp))
                OutlinedButton(
                    modifier = Modifier.fillMaxWidth(),
                    enabled = selectedBranch != null,
                    onClick = { managerExpanded = true }
                ) {
                    Text(manager.ifBlank { "Seleccionar encargado de la sucursal" })
                }
                DropdownMenu(
                    expanded = managerExpanded,
                    onDismissRequest = { managerExpanded = false }
                ) {
                    branchManagers.forEach { user ->
                        DropdownMenuItem(
                            text = { Text(user.fullName) },
                            onClick = {
                                manager = user.fullName
                                managerExpanded = false
                            }
                        )
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                Button(
                    modifier = Modifier.fillMaxWidth(),
                    enabled = selectedBranch != null,
                    onClick = {
                        val branch = selectedBranch ?: return@Button

                        viewModel.addDepartment(
                            branchId = branch.id,
                            name = name,
                            code = code,
                            description = description,
                            manager = manager
                        )

                        name = ""
                        code = ""
                        description = ""
                        manager = ""
                    }
                ) {
                    Text("Guardar departamento")
                }

                Spacer(modifier = Modifier.height(12.dp))

                OutlinedButton(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = onBack
                ) {
                    Text("⬅ Volver")
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text("Departamentos registrados")

                Spacer(modifier = Modifier.height(8.dp))
            }

            items(departments) { department ->

                val branchName = branches
                    .find { it.id == department.branchId }
                    ?.name ?: "Sucursal no encontrada"

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    elevation = CardDefaults.cardElevation(3.dp)
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp)
                    ) {
                        Text("${department.name} (${department.code})")
                        Text("Sucursal: $branchName")
                        Text(department.description)
                        Text("Encargado: ${department.manager}")

                        Spacer(modifier = Modifier.height(8.dp))

                        Button(
                            modifier = Modifier.fillMaxWidth(),
                            onClick = {
                                viewModel.deleteDepartment(department)
                            }
                        ) {
                            Text("Eliminar")
                        }
                    }
                }
            }
        }
    }
}
