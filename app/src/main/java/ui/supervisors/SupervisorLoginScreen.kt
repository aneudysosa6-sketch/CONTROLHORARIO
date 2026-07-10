package com.example.controlhorario.ui.supervisors

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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.repository.SupervisorRepository
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETStatusText
import com.example.controlhorario.ui.components.OSINETTextField
import kotlinx.coroutines.launch

@Composable
fun SupervisorLoginScreen(
    onLoggedIn: (Int) -> Unit,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    val db = DatabaseProvider.getDatabase(context)
    val repository = remember { SupervisorRepository(db.supervisorDao()) }
    val scope = rememberCoroutineScope()
    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }

    OSINETScreen {
        Spacer(Modifier.height(40.dp))
        OSINETHeader(
            title = "Acceso Supervisor",
            subtitle = "Ingrese sus credenciales para continuar"
        )
        Spacer(Modifier.height(28.dp))
        OSINETTextField(
            value = username,
            onValueChange = { username = it; message = "" },
            label = "Usuario",
            modifier = Modifier.fillMaxWidth()
        )
        Spacer(Modifier.height(12.dp))
        OSINETTextField(
            value = password,
            onValueChange = { password = it; message = "" },
            label = "Contraseña",
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation()
        )
        Spacer(Modifier.height(16.dp))
        OSINETStatusText(message, if (message.isBlank()) OSINETColors.TextSecondary else OSINETColors.Warning)
        Spacer(Modifier.height(8.dp))
        OSINETButton(text = "Entrar como supervisor", onClick = {
            scope.launch {
                val supervisor = repository.login(username.trim(), password.trim())
                if (supervisor == null) message = "Usuario o contraseña incorrectos." else onLoggedIn(supervisor.id)
            }
        })
        Spacer(Modifier.height(10.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}
