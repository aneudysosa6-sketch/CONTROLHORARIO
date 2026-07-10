package com.example.controlhorario.ui.login

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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavController
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.repository.AppUserRepository
import com.example.controlhorario.session.UserSessionManager
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETLogo
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun LoginScreen(
    navController: NavController
) {
    val context = LocalContext.current
    val database = DatabaseProvider.getDatabase(context)

    val appUserViewModel: AppUserViewModel = viewModel(
        factory = AppUserViewModelFactory(
            AppUserRepository(database.appUserDao())
        )
    )

    val currentUser by UserSessionManager.currentUser.collectAsState()
    val loginError by appUserViewModel.loginError.collectAsState()

    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    LaunchedEffect(Unit) {
        appUserViewModel.createDefaultAdminIfNeeded()
    }

    LaunchedEffect(currentUser) {
        if (currentUser != null) {
            navController.navigate("home") {
                popUpTo("admin_login") {
                    inclusive = true
                }
            }
        }
    }

    OSINETScreen {
        OSINETLogo(subtitle = "CONTROL HORARIO IA")

        Spacer(modifier = Modifier.height(30.dp))

        OSINETTextField(
            value = username,
            onValueChange = {
                username = it
                appUserViewModel.clearError()
            },
            label = "Usuario",
            modifier = Modifier.fillMaxWidth()
        )

        Spacer(modifier = Modifier.height(12.dp))

        OSINETTextField(
            value = password,
            onValueChange = {
                password = it
                appUserViewModel.clearError()
            },
            label = "Contraseña",
            modifier = Modifier.fillMaxWidth(),
            visualTransformation = PasswordVisualTransformation()
        )

        Spacer(modifier = Modifier.height(16.dp))

        if (loginError.isNotBlank()) {
            Text(loginError, color = OSINETColors.Warning)
            Spacer(modifier = Modifier.height(12.dp))
        }

        OSINETButton(
            text = "INICIAR SESIÓN",
            onClick = {
                appUserViewModel.login(
                    username = username,
                    password = password
                )
            }
        )


    }
}
