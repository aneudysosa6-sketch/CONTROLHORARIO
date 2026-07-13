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
import com.example.controlhorario.auth.AuthRepository
import com.example.controlhorario.auth.RoomUsernameResolver
import com.example.controlhorario.auth.SupabaseAuthApi
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
            AppUserRepository(database.appUserDao()),
            AuthRepository(RoomUsernameResolver(database.appUserDao()), SupabaseAuthApi())
        )
    )

    val currentUser by UserSessionManager.currentUser.collectAsState()
    val loginError by appUserViewModel.loginError.collectAsState()
    val loginLoading by appUserViewModel.loginLoading.collectAsState()

    var username by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }

    LaunchedEffect(currentUser) {
        if (currentUser != null) {
            navController.navigate("home") {
                popUpTo("admin_login") {
                    inclusive = true
                }
            }
        }
    }

    PremiumLoginContent(
        username = username,
        password = password,
        error = loginError,
        loading = loginLoading,
        onUsernameChange = {
            username = it
            appUserViewModel.clearError()
        },
        onPasswordChange = {
            password = it
            appUserViewModel.clearError()
        },
        onLogin = {
            appUserViewModel.login(username = username, password = password)
        }
    )
}
