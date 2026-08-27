package com.example.controlhorario.ui.face

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.face.AndroidTerminalFaceEnrollmentGateway
import com.example.controlhorario.model.EmployeeCodePolicy
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETLogo
import com.example.controlhorario.ui.components.OSINETScreen

@Composable
fun TerminalFaceEnrollmentScreen(
    onBack: () -> Unit,
    onRegistered: () -> Unit,
) {
    val context = LocalContext.current.applicationContext
    val database = remember(context) { DatabaseProvider.getDatabase(context) }
    val registrationViewModel: FaceRegistrationViewModel = viewModel(
        factory = FaceRegistrationViewModelFactory(
            context = context,
            employees = EmployeeRepository(database.employeeDao()),
            faces = EmployeeFaceBiometricRepository(database.employeeFaceBiometricDao()),
            mode = FaceRegistrationMode.TERMINAL_AUTHORIZED,
            terminalEnrollment = AndroidTerminalFaceEnrollmentGateway(context),
        ),
    )
    val state by registrationViewModel.state.collectAsState()
    var employeeCode by remember { mutableStateOf("") }

    if (state.employee != null) {
        FaceRegistrationScreen(
            viewModel = registrationViewModel,
            onRegistered = { onRegistered() },
            onBack = onBack,
            backLabel = "Volver a la cámara",
            initialRegistrationOnly = true,
        )
        return
    }

    OSINETScreen {
        OSINETLogo(subtitle = "CONTROL HORARIO · TERMINAL FACIAL")
        Spacer(Modifier.height(12.dp))
        OSINETHeader("Registrar rostro nuevo", "Introduzca el código del empleado")
        Spacer(Modifier.height(16.dp))
        OutlinedTextField(
            value = employeeCode,
            onValueChange = { value -> employeeCode = value.filter(Char::isDigit).take(EmployeeCodePolicy.LENGTH) },
            label = { Text("Código de empleado") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            enabled = !state.validating,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Button(
                onClick = { registrationViewModel.find(employeeCode) },
                enabled = EmployeeCodePolicy.isValid(employeeCode) && !state.validating,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (state.validating) CircularProgressIndicator() else Text("Buscar empleado")
            }
            if (state.message.isNotBlank()) Text(state.message)
            OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) {
                Text("Volver a la cámara")
            }
        }
    }
}
