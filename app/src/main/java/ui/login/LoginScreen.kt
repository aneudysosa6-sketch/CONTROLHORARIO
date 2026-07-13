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
    var submitting by remember { mutableStateOf(false) }

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

    LaunchedEffect(loginError) {
        if (loginError.isNotBlank()) submitting = false
    }

    PremiumLoginContent(
        username = username,
        password = password,
        error = loginError,
        loading = submitting,
        onUsernameChange = {
            username = it
            appUserViewModel.clearError()
        },
        onPasswordChange = {
            password = it
            appUserViewModel.clearError()
        },
        onLogin = {
            submitting = true
            appUserViewModel.login(username = username, password = password)
        }
    )
}
