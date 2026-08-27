package com.example.controlhorario.ui.navigation

import android.content.Context
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.produceState
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.rememberNavController
import com.example.controlhorario.R
import com.example.controlhorario.attendance.AttendanceDeviceSession
import com.example.controlhorario.attendance.AttendanceSyncClient
import com.example.controlhorario.attendance.JourneyCurrentStateSynchronizer
import com.example.controlhorario.auth.AndroidAuthRepositoryFactory
import com.example.controlhorario.auth.AuthenticatedLogin
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.database.DeviceEnrollmentEntity
import com.example.controlhorario.device.DeviceEnrollmentScreen
import com.example.controlhorario.device.DeviceSyncScheduler
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.face.FaceTemplateInvalidationBus

import com.example.controlhorario.face.PendingFaceEnrollmentCountStore
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.JourneyRepository
import com.example.controlhorario.repository.KioskSettingsRepository
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.security.TerminalAccess
import com.example.controlhorario.security.TerminalAccessKind
import com.example.controlhorario.security.TerminalAuthorizationManager
import com.example.controlhorario.security.TerminalVisibleDestination
import com.example.controlhorario.security.TerminalVisibleDestinationPolicy
import com.example.controlhorario.session.KioskModeManager
import com.example.controlhorario.session.SessionCoordinator
import com.example.controlhorario.ui.employees.EmployeeViewModel
import com.example.controlhorario.ui.employees.EmployeeViewModelFactory
import com.example.controlhorario.ui.face.FaceIdentificationScreen
import com.example.controlhorario.ui.face.FaceIdentificationViewModel
import com.example.controlhorario.ui.face.FaceIdentificationViewModelFactory
import com.example.controlhorario.ui.face.FaceTemplateSyncGateway
import com.example.controlhorario.ui.face.TerminalCameraStartupSynchronizer
import com.example.controlhorario.ui.face.TerminalFaceEnrollmentScreen
import com.example.controlhorario.ui.punch.AuthRepositoryKioskExitAuthenticator
import com.example.controlhorario.ui.punch.JourneyBiometricGate
import com.example.controlhorario.ui.punch.JourneyViewModel
import com.example.controlhorario.ui.punch.JourneyViewModelFactory
import com.example.controlhorario.ui.punch.KioskExitAuthScreen
import com.example.controlhorario.ui.punch.KioskExitAuthViewModel
import com.example.controlhorario.ui.punch.KioskExitAuthViewModelFactory
import com.example.controlhorario.ui.punch.KioskExitCoordinator
import com.example.controlhorario.ui.punch.KioskExitRuntime
import com.example.controlhorario.ui.punch.Rc2EmployeeAttendanceScreen
import com.example.controlhorario.ui.punch.TerminalJourneySpeaker
import java.text.DateFormat
import java.time.Instant
import java.time.LocalDate
import java.util.Date
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private enum class TerminalScreen {
    CAMERA,
    FACE_ENROLLMENT,
    ATTENDANCE,
    EXIT_AUTH,
    MAINTENANCE,
}

@Composable
fun AppNavigation(
    @Suppress("UNUSED_PARAMETER")
    navController: NavHostController = rememberNavController(),
) {
    val context = LocalContext.current
    val appContext = context.applicationContext
    val database = remember(appContext) { DatabaseProvider.getDatabase(appContext) }
    val identity = remember(appContext) { DeviceIdentityManager(appContext) }
    val journeySpeaker = remember(appContext) { TerminalJourneySpeaker(appContext) }
    DisposableEffect(journeySpeaker) {
        onDispose { journeySpeaker.close() }
    }
    val authorization by TerminalAuthorizationManager.state.collectAsState()
    var screenName by remember { mutableStateOf(TerminalScreen.CAMERA.name) }
    var employeeId by remember { mutableIntStateOf(0) }
    var cameraRevision by remember { mutableIntStateOf(0) }
    var requireFaceExit by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(appContext) {
        TerminalAuthorizationManager.init(appContext)
        while (true) {
            delay(30_000L)
            TerminalAuthorizationManager.refreshClock()
        }
    }

    val access = remember(authorization, identity.deviceId) {
        TerminalAuthorizationManager.access(identity)
    }

    fun returnToCamera(awaitFaceExit: Boolean = false) {
        JourneyBiometricGate.clear()
        employeeId = 0
        cameraRevision += 1
        requireFaceExit = awaitFaceExit
        screenName = TerminalScreen.CAMERA.name
    }

    LaunchedEffect(access.kind) {
        if (access.kind != TerminalAccessKind.AUTHORIZED) {
            JourneyBiometricGate.clear()
            employeeId = 0
            requireFaceExit = false
            screenName = TerminalScreen.CAMERA.name
        }
    }

    when (TerminalVisibleDestinationPolicy.resolve(access.kind)) {
        TerminalVisibleDestination.REGISTRATION -> {
            DeviceEnrollmentScreen(onReady = { returnToCamera() })
        }

        TerminalVisibleDestination.UNAUTHORIZED -> {
            val validationRequired = access.kind == TerminalAccessKind.VALIDATION_REQUIRED
            if (validationRequired) LaunchedEffect(identity.deviceId) {
                DeviceSyncScheduler.start(appContext)
            }
            TerminalUnauthorizedScreen(
                access = access,
                validating = validationRequired,
                onRetry = { DeviceSyncScheduler.start(appContext) },
                onReEnroll = {
                    if (access.canReEnroll) {
                        scope.launch {
                            withContext(Dispatchers.IO) {
                                database.employeeFaceBiometricDao().deleteAll()
                                database.deviceEnrollmentDao().clear()
                                identity.clearEnrollment()
                            }
                            FaceTemplateInvalidationBus.invalidate()
                            SessionCoordinator.logout()
                            TerminalAuthorizationManager.clear()
                            returnToCamera()
                        }
                    }
                },
            )
        }

        TerminalVisibleDestination.CAMERA -> {
            when (TerminalScreen.valueOf(screenName)) {
                TerminalScreen.CAMERA -> TerminalCamera(
                    context = appContext,
                    cameraRevision = cameraRevision,
                    requireFaceExit = requireFaceExit,
                    onFaceExitConfirmed = { requireFaceExit = false },
                    onIdentified = { identifiedEmployeeId ->
                        if (TerminalAuthorizationManager.canRecord(identity)) {
                            JourneyBiometricGate.open(
                                identifiedEmployeeId,
                                requireNotNull(identity.deviceId),
                            )
                            employeeId = identifiedEmployeeId
                            screenName = TerminalScreen.ATTENDANCE.name
                        }
                    },
                    onRegisterFace = { screenName = TerminalScreen.FACE_ENROLLMENT.name },
                    onProtectedExit = {
                        JourneyBiometricGate.clear()
                        screenName = TerminalScreen.EXIT_AUTH.name
                    },
                )

                TerminalScreen.FACE_ENROLLMENT -> TerminalFaceEnrollmentScreen(
                    onBack = ::returnToCamera,
                    onRegistered = {
                        DeviceSyncScheduler.start(appContext)
                        returnToCamera()
                    },
                )

                TerminalScreen.ATTENDANCE -> TerminalAttendance(
                    context = appContext,
                    employeeId = employeeId,
                    onCancel = { returnToCamera() },
                    onActionSaved = { employeeName, action ->
                        journeySpeaker.speak(action, employeeName)
                        returnToCamera(awaitFaceExit = true)
                    },
                )

                TerminalScreen.EXIT_AUTH -> TerminalProtectedExit(
                    onAuthenticated = {
                        JourneyBiometricGate.clear()
                        screenName = TerminalScreen.MAINTENANCE.name
                    },
                    onCancelled = ::returnToCamera,
                )

                TerminalScreen.MAINTENANCE -> TerminalMaintenanceScreen(
                    enrollmentDao = database.deviceEnrollmentDao(),
                    authorization = access,
                    onSynchronize = { DeviceSyncScheduler.start(appContext) },
                    onReturn = {
                        SessionCoordinator.logout()
                        KioskModeManager.activate()
                        returnToCamera()
                    },
                    onUnenroll = {
                        scope.launch {
                            withContext(Dispatchers.IO) {
                                database.employeeFaceBiometricDao().deleteAll()
                                database.deviceEnrollmentDao().clear()
                                identity.clearEnrollment()
                            }
                            FaceTemplateInvalidationBus.invalidate()
                            SessionCoordinator.logout()
                            TerminalAuthorizationManager.clear()
                            returnToCamera()
                        }
                    },
                )
            }
        }
    }
}

@Composable
private fun TerminalCamera(
    context: Context,
    cameraRevision: Int,
    requireFaceExit: Boolean,
    onFaceExitConfirmed: () -> Unit,
    onIdentified: (Int) -> Unit,
    onRegisterFace: () -> Unit,
    onProtectedExit: () -> Unit,
) {
    val database = remember(context) { DatabaseProvider.getDatabase(context) }
    val identity = remember(context) { DeviceIdentityManager(context) }
    val deviceId = identity.deviceId ?: return
    PendingFaceEnrollmentCountStore.init(context)
    val pendingFaceCount by PendingFaceEnrollmentCountStore.count.collectAsState()

    val faceRepository = remember(database) {
        EmployeeFaceBiometricRepository(database.employeeFaceBiometricDao())
    }
    val employeeSyncUrl = stringResource(R.string.employee_sync_url)
    val faceTemplateSyncGateway = remember(context, database, deviceId, employeeSyncUrl, identity) {
        FaceTemplateSyncGateway {
            withContext(Dispatchers.IO) {
                val credential = identity.credential() ?: return@withContext false
                runCatching {
                    com.example.controlhorario.device.EmployeeSyncRepository(database).sync(
                        com.example.controlhorario.device.EmployeeSyncClient(employeeSyncUrl),
                        deviceId,
                        credential,
                    )
                }.onSuccess { summary ->
                    summary.authorization?.let {
                        TerminalAuthorizationManager.recordAuthorized(
                            it.validatedAt,
                            it.credentialExpiresAt,
                            it.offlineLeaseExpiresAt,
                        )
                    } ?: database.deviceEnrollmentDao().current()?.credentialExpiresAt?.let {
                        TerminalAuthorizationManager.recordAuthorizedWithCredentialLease(
                            Instant.now().toString(),
                            it,
                        )
                    }
                }.onSuccess { PendingFaceEnrollmentCountStore.update(context, it.pendingFaceCount) }.isSuccess
            }
        }
    }
    val startupSynchronizer = remember(faceTemplateSyncGateway) {
        TerminalCameraStartupSynchronizer(faceTemplateSyncGateway)
    }
    LaunchedEffect(deviceId, cameraRevision, startupSynchronizer) {
        startupSynchronizer.synchronizePendingEnrollments()
    }
    val identificationViewModel: FaceIdentificationViewModel = viewModel(
        key = "terminal-camera-$cameraRevision",
        factory = FaceIdentificationViewModelFactory(
            deviceId = deviceId,
            enrollmentDao = database.deviceEnrollmentDao(),
            settingsRepository = KioskSettingsRepository(database.kioskSettingsDao()),
            employeeRepository = EmployeeRepository(database.employeeDao()),
            faceRepository = faceRepository,
            syncGateway = faceTemplateSyncGateway,
        ),
    )
    FaceIdentificationScreen(
        viewModel = identificationViewModel,
        onIdentified = onIdentified,
        onKioskExit = onProtectedExit,
        requireFaceExit = requireFaceExit,
        onFaceExitConfirmed = onFaceExitConfirmed,
        pendingFaceCount = pendingFaceCount,
        onRegisterFace = onRegisterFace,
    )
}

@Composable
private fun TerminalAttendance(
    context: Context,
    employeeId: Int,
    onCancel: () -> Unit,
    onActionSaved: (String, JourneyAction) -> Unit,
) {
    val database = remember(context) { DatabaseProvider.getDatabase(context) }
    val identity = remember(context) { DeviceIdentityManager(context) }
    val routeDeviceId = identity.deviceId
    val authorizedOnEntry = remember(employeeId, routeDeviceId) {
        routeDeviceId != null &&
            TerminalAuthorizationManager.canRecord(identity) &&
            JourneyBiometricGate.isAuthorized(employeeId, routeDeviceId)
    }
    if (!authorizedOnEntry) {
        LaunchedEffect(employeeId) { onCancel() }
        return
    }

    val journeyRepository = remember(database, context) {
        JourneyRepository(
            database.journeyDao(),
            database.employeeDao(),
            JourneyCurrentStateSynchronizer(
                journeyDao = database.journeyDao(),
                employeeDao = database.employeeDao(),
                gateway = AttendanceSyncClient(context.getString(R.string.attendance_sync_url)),
                sessionProvider = {
                    val currentIdentity = DeviceIdentityManager(context)
                    val currentDeviceId = currentIdentity.deviceId
                    val credential = currentIdentity.credential()
                    if (currentDeviceId == null || credential == null ||
                        !TerminalAuthorizationManager.canRecord(currentIdentity)
                    ) {
                        null
                    } else {
                        AttendanceDeviceSession(currentDeviceId, credential)
                    }
                },
            ),
        )
    }
    val employeeViewModel: EmployeeViewModel = viewModel(
        factory = EmployeeViewModelFactory(EmployeeRepository(database.employeeDao())),
    )
    val journeyViewModel: JourneyViewModel = viewModel(
        key = "terminal-attendance-$employeeId",
        factory = JourneyViewModelFactory(
            context,
            journeyRepository,
            employeeId,
            LocalDate.now().toString(),
        ),
    )
    val employees by employeeViewModel.employees.collectAsState()
    Rc2EmployeeAttendanceScreen(
        employee = employees.firstOrNull { it.id == employeeId },
        viewModel = journeyViewModel,
        onCancel = onCancel,
        onActionSaved = onActionSaved,
    )
}

@Composable
private fun TerminalProtectedExit(
    onAuthenticated: () -> Unit,
    onCancelled: () -> Unit,
) {
    val database = DatabaseProvider.getDatabase(LocalContext.current)
    val coordinator = remember(database) {
        KioskExitCoordinator(
            authenticator = AuthRepositoryKioskExitAuthenticator(
                AndroidAuthRepositoryFactory.create(database.appUserDao()),
            ),
            runtime = object : KioskExitRuntime {
                override fun startSession(login: AuthenticatedLogin) {
                    SessionCoordinator.start(login)
                }

                override suspend fun deactivateAndPersist(): Boolean =
                    KioskModeManager.deactivateAndPersist()

                override fun isKioskActive(): Boolean = KioskModeManager.isActive.value

                override fun clearSession() {
                    SessionCoordinator.logout()
                }
            },
        )
    }
    val exitViewModel: KioskExitAuthViewModel = viewModel(
        factory = KioskExitAuthViewModelFactory(coordinator),
    )
    KioskExitAuthScreen(
        viewModel = exitViewModel,
        onAuthenticated = { _, _ -> onAuthenticated() },
        onCancelled = onCancelled,
    )
}

@Composable
private fun TerminalUnauthorizedScreen(
    access: TerminalAccess,
    validating: Boolean,
    onRetry: () -> Unit,
    onReEnroll: () -> Unit,
) {
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = "TERMINAL NO AUTORIZADO",
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            Text(
                text = if (validating) {
                    "La autorización debe validarse antes de abrir la cámara."
                } else {
                    access.message.ifBlank { "Este dispositivo no puede registrar jornadas." }
                },
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(24.dp))
            Button(onClick = onRetry, modifier = Modifier.fillMaxWidth()) {
                Text("Reintentar validación")
            }
            if (access.canReEnroll) {
                Spacer(Modifier.height(12.dp))
                OutlinedButton(onClick = onReEnroll, modifier = Modifier.fillMaxWidth()) {
                    Text("Registrar con otro código")
                }
            }
        }
    }
}

@Composable
private fun TerminalMaintenanceScreen(
    enrollmentDao: com.example.controlhorario.database.DeviceEnrollmentDao,
    authorization: TerminalAccess,
    onSynchronize: () -> Unit,
    onReturn: () -> Unit,
    onUnenroll: () -> Unit,
) {
    val enrollment by produceState<DeviceEnrollmentEntity?>(initialValue = null, enrollmentDao) {
        value = withContext(Dispatchers.IO) { enrollmentDao.current() }
    }
    var confirmUnenroll by remember { mutableStateOf(false) }
    Surface(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier.fillMaxSize().padding(28.dp),
            verticalArrangement = Arrangement.Center,
        ) {
            Text("Mantenimiento del Terminal", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(18.dp))
            TerminalDetail("Dispositivo", enrollment?.deviceId ?: "No disponible")
            TerminalDetail("Sucursal", enrollment?.branchId ?: "General")
            TerminalDetail("Tipo", enrollment?.usageType ?: "GENERAL")
            TerminalDetail(
                "Departamentos",
                enrollment?.departmentIds?.takeIf(String::isNotBlank) ?: "Todos los autorizados",
            )
            TerminalDetail(
                "Última sincronización",
                enrollment?.lastEmployeeSyncAt?.let {
                    DateFormat.getDateTimeInstance().format(Date(it))
                } ?: "Pendiente",
            )
            TerminalDetail("Autorización", authorization.message.ifBlank { "Vigente" })
            Spacer(Modifier.height(22.dp))
            Button(onClick = onSynchronize, modifier = Modifier.fillMaxWidth()) {
                Text("Sincronizar ahora")
            }
            Spacer(Modifier.height(10.dp))
            Button(onClick = onReturn, modifier = Modifier.fillMaxWidth()) {
                Text("Volver a la cámara")
            }
            Spacer(Modifier.height(10.dp))
            OutlinedButton(
                onClick = { confirmUnenroll = true },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("Desregistrar Terminal")
            }
        }
    }
    if (confirmUnenroll) {
        AlertDialog(
            onDismissRequest = { confirmUnenroll = false },
            title = { Text("Desregistrar Terminal") },
            text = {
                Text(
                    "Se eliminarán la credencial y los rostros locales. " +
                        "Los eventos de jornada pendientes se conservarán.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmUnenroll = false
                    onUnenroll()
                }) {
                    Text("Desregistrar")
                }
            },
            dismissButton = {
                TextButton(onClick = { confirmUnenroll = false }) {
                    Text("Cancelar")
                }
            },
        )
    }
}

@Composable
private fun TerminalDetail(label: String, value: String) {
    Text(label, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
    Text(value, style = MaterialTheme.typography.bodyMedium)
    Spacer(Modifier.height(10.dp))
}