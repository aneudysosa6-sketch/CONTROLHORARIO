package com.example.controlhorario.ui.punch

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.repository.AppUserRepository
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField
import kotlinx.coroutines.launch

@Composable
fun KioskExitAuthScreen(
    repository: AppUserRepository,
    onAuthenticated: (AppUserEntity) -> Unit,
    onCancelled: () -> Unit
) {
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var authenticating by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    BackHandler(onBack = onCancelled)

    OSINETScreen {
        OSINETHeader(
            title = "Salir del Modo PIN",
            subtitle = "Ingrese usuario y contraseña para abrir el panel administrativo"
        )
        Spacer(Modifier.height(24.dp))
        OSINETTextField(
            value = username,
            onValueChange = { username = it },
            label = "Usuario",
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OSINETTextField(
            value = password,
            onValueChange = { password = it },
            label = "Contraseña",
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation()
        )
        Spacer(Modifier.height(18.dp))
        OSINETButton(
            text = "AUTENTICAR Y SALIR",
            enabled = username.isNotBlank() && password.isNotBlank() && !authenticating,
            onClick = {
                authenticating = true
                scope.launch {
                    val user = repository.login(username, password)
                    authenticating = false
                    if (user == null) {
                        password = ""
                        onCancelled()
                    } else {
                        repository.updateLastLogin(user.id, System.currentTimeMillis().toString())
                        onAuthenticated(user)
                    }
                }
            }
        )
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton("Volver al Modo PIN", onCancelled)
    }
}
