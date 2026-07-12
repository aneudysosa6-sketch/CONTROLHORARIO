package com.example.controlhorario.ui.employees

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.BranchEntity
import com.example.controlhorario.database.DepartmentEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun AddEmployeeScreen(
    viewModel: EmployeeViewModel,
    branches: List<BranchEntity>,
    departments: List<DepartmentEntity>,
    initialEmployee: Employee? = null,
    isEditMode: Boolean = false,
    onRegisterFingerprint: (String) -> Unit,
    onSaved: () -> Unit = {},
    onBack: () -> Unit
) {
    var nombre by remember { mutableStateOf("") }
    var cedula by remember { mutableStateOf("") }
    var telefono by remember { mutableStateOf("") }
    var cargo by remember { mutableStateOf("") }
    var sueldo by remember { mutableStateOf("") }
    var lunchHours by remember { mutableStateOf("") }
    var profilePhotoUri by remember { mutableStateOf("") }
    var mensaje by remember { mutableStateOf("") }
    val codigoGenerado by viewModel.lastCreatedCode.collectAsState()
    val photoLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) profilePhotoUri = uri.toString()
    }

    var selectedBranch by remember { mutableStateOf<BranchEntity?>(null) }
    var selectedDepartment by remember { mutableStateOf<DepartmentEntity?>(null) }

    var branchExpanded by remember { mutableStateOf(false) }
    var departmentExpanded by remember { mutableStateOf(false) }

    LaunchedEffect(initialEmployee?.id) {
        initialEmployee?.let { employee ->
            val fields=EmployeeEditEngine.fieldsFrom(employee)
            nombre = fields.nombre;cedula = fields.cedula;telefono = fields.telefono;cargo = fields.cargo
            sueldo = fields.sueldo.toString();lunchHours = fields.lunchHours.toString();profilePhotoUri = fields.profilePhotoUri
        }
    }
    LaunchedEffect(initialEmployee?.id, branches) {
        if (isEditMode && selectedBranch == null) selectedBranch = branches.firstOrNull { it.id == initialEmployee?.branchId }
    }
    LaunchedEffect(initialEmployee?.id, departments) {
        if (isEditMode && selectedDepartment == null) selectedDepartment = departments.firstOrNull { it.id == initialEmployee?.departmentId }
    }

    val filteredDepartments = departments.filter {
        it.branchId == selectedBranch?.id
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = if (isEditMode) "Editar empleado" else "Crear empleado",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        OSINETTextField(
            value = nombre,
            onValueChange = { nombre = it },
            label = "Nombre completo",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = cedula,
            onValueChange = { cedula = it },
            label = "Cédula",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = telefono,
            onValueChange = { telefono = it },
            label = "Teléfono",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OutlinedButton(
            onClick = { photoLauncher.launch(arrayOf("image/*")) },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (profilePhotoUri.isBlank()) "Agregar foto de perfil" else "Foto de perfil seleccionada")
        }

        Spacer(modifier = Modifier.height(10.dp))

        Text("Sucursal")

        Spacer(modifier = Modifier.height(6.dp))

        OutlinedButton(
            onClick = {
                branchExpanded = true
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(selectedBranch?.name ?: initialEmployee?.remoteBranchName?.takeIf { it.isNotBlank() } ?: "Seleccionar sucursal")
        }

        DropdownMenu(
            expanded = branchExpanded,
            onDismissRequest = {
                branchExpanded = false
            }
        ) {
            branches.forEach { branch ->
                DropdownMenuItem(
                    text = {
                        Text("${branch.name} - ${branch.city}")
                    },
                    onClick = {
                        selectedBranch = branch
                        selectedDepartment = null
                        branchExpanded = false
                    }
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        Text("Departamento")

        Spacer(modifier = Modifier.height(6.dp))

        OutlinedButton(
            onClick = {
                if (selectedBranch != null) {
                    departmentExpanded = true
                }
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(selectedDepartment?.name ?: initialEmployee?.remoteDepartmentName?.takeIf { it.isNotBlank() } ?: initialEmployee?.departamento?.takeIf { it.isNotBlank() } ?: "Seleccionar departamento")
        }

        DropdownMenu(
            expanded = departmentExpanded,
            onDismissRequest = {
                departmentExpanded = false
            }
        ) {
            filteredDepartments.forEach { department ->
                DropdownMenuItem(
                    text = {
                        Text(department.name)
                    },
                    onClick = {
                        selectedDepartment = department
                        departmentExpanded = false
                    }
                )
            }
        }

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = cargo,
            onValueChange = { cargo = it },
            label = "Cargo",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = sueldo,
            onValueChange = { sueldo = it },
            label = "Sueldo quincenal",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(
            value = lunchHours,
            onValueChange = { lunchHours = it.filter { char -> char.isDigit() || char == '.' } },
            label = "Tiempo de almuerzo en horas",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(10.dp))

        Text(if(isEditMode) "Código de empleado: ${initialEmployee?.employeeCode.orEmpty()}" else "Código de empleado: se asignará automáticamente en secuencia 00001, 00002, 00003...")

        Spacer(modifier = Modifier.height(16.dp))

        if (mensaje.isNotEmpty()) {
            Text(mensaje)
            Spacer(modifier = Modifier.height(8.dp))
        }

        if (!isEditMode && codigoGenerado.isNotBlank()) {
            Text("Código numérico asignado: $codigoGenerado")
            Spacer(modifier = Modifier.height(12.dp))
        }

        OSINETButton(
            text = if(isEditMode) "Guardar cambios" else "Crear empleado",
            onClick = {
                val branch = selectedBranch
                val department = selectedDepartment

                val departmentName = department?.name ?: initialEmployee?.departamento ?: "General"
                val branchId = branch?.id ?: initialEmployee?.branchId ?: 0
                val departmentId = department?.id ?: initialEmployee?.departmentId ?: 0

                val nuevoEmpleado = Employee(
                    nombre = nombre,
                    cedula = cedula,
                    telefono = telefono,
                    profilePhotoUri = profilePhotoUri,
                    cargo = cargo,
                    departamento = departmentName,
                    branchId = branchId,
                    departmentId = departmentId,
                    sueldo = sueldo.toDoubleOrNull() ?: 0.0,
                    lunchHours = lunchHours.toDoubleOrNull() ?: 0.0
                )

                if(isEditMode&&initialEmployee!=null){
                    val fields=EmployeeEditableFields(nombre,cedula,telefono,profilePhotoUri,cargo,departmentName,branchId,departmentId,nuevoEmpleado.sueldo,nuevoEmpleado.lunchHours)
                    viewModel.updateEmployee(EmployeeEditEngine.merge(initialEmployee,fields),onSaved)
                    mensaje="Cambios guardados correctamente"
                }else{
                    viewModel.addEmployee(nuevoEmpleado)
                    nombre = "";cedula = "";telefono = "";cargo = "";sueldo = "";lunchHours = "";profilePhotoUri = "";selectedBranch = null;selectedDepartment = null
                    mensaje = "Empleado creado correctamente. Código asignado: se mostrará abajo."
                }
            }
        )

        if (!isEditMode && codigoGenerado.isNotBlank()) {
            Spacer(modifier = Modifier.height(12.dp))
            OSINETButton(
                text = "Registrar huella a este empleado",
                onClick = { onRegisterFingerprint(codigoGenerado) }
            )
        }

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}
