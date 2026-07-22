package com.example.controlhorario.ui.punch

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun KioskExitAuthScreen(
    viewModel: KioskExitAuthViewModel,
    onAuthenticated: (userId: Int, roleCode: String) -> Unit,
    onCancelled: () -> Unit
) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    val state by viewModel.state.collectAsState()

    LaunchedEffect(viewModel) {
        viewModel.events.collect { event ->
            when (event) {
                is KioskExitAuthEvent.NavigateHome ->
                    onAuthenticated(event.userId, event.roleCode)
            }
        }
    }

    LaunchedEffect(state.errorMessage) {
        if (state.errorMessage != null) password = ""
    }

    BackHandler(onBack = onCancelled)

    OSINETScreen {
        OSINETHeader(
            title = "Salir del modo empleado",
            subtitle = "Ingrese usuario y contraseña para abrir el panel administrativo"
        )
        Spacer(Modifier.height(24.dp))
        OSINETTextField(
            value = username,
            onValueChange = {
                username = it
                viewModel.clearError()
            },
            label = "Usuario",
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OSINETTextField(
            value = password,
            onValueChange = {
                password = it
                viewModel.clearError()
            },
            label = "Contraseña",
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation()
        )
        state.errorMessage?.let { message ->
            Spacer(Modifier.height(12.dp))
            Text(text = message, color = OSINETColors.Danger)
        }
        Spacer(Modifier.height(18.dp))
        OSINETButton(
            text = if (state.authenticating) "AUTENTICANDO..." else "AUTENTICAR Y SALIR",
            enabled = username.isNotBlank() && password.isNotBlank() && !state.authenticating,
            onClick = {
                viewModel.authenticate(username, password)
            }
        )
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton("Volver al modo empleado", onCancelled)
    }
}
