package com.example.controlhorario.ui.navigation

import android.util.Log
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.Checkbox
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.device.DeviceEnrollmentScreen
import com.example.controlhorario.device.DeviceSyncScheduler
import com.example.controlhorario.device.EmployeeSyncDashboardScreen
import com.example.controlhorario.device.EmployeeSyncDashboardViewModel
import com.example.controlhorario.device.EmployeeSyncDashboardViewModelFactory
import com.example.controlhorario.auth.AuthSessionStore
import com.example.controlhorario.dashboard.AndroidDashboardPanel
import com.example.controlhorario.dashboard.AndroidDashboardViewModel
import com.example.controlhorario.dashboard.AndroidDashboardViewModelFactory
import com.example.controlhorario.dashboard.AuthenticatedSupervisorDashboard
import com.example.controlhorario.dashboard.DashboardDestination
import com.example.controlhorario.employeeportal.EmployeeSelfServiceScreen
import com.example.controlhorario.dashboard.DashboardRoutePolicy
import com.example.controlhorario.dashboard.DashboardState
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.database.AppUserEntity
import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.JourneyRepository
import com.example.controlhorario.repository.AppEventRepository
import com.example.controlhorario.repository.BranchRepository
import com.example.controlhorario.repository.CompanySettingsRepository
import com.example.controlhorario.repository.LaborCalendarRepository
import com.example.controlhorario.repository.PayrollSettingsRepository
import com.example.controlhorario.repository.PayrollHistoryRepository
import com.example.controlhorario.repository.EmployeeDocumentRepository
import com.example.controlhorario.repository.EmployeePayrollSettingsRepository
import com.example.controlhorario.repository.EmployeePermissionRequestRepository
import com.example.controlhorario.repository.LoanRepository
import com.example.controlhorario.repository.VacationRepository
import com.example.controlhorario.repository.WorkScheduleTemplateRepository
import com.example.controlhorario.repository.DepartmentRepository
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.SupervisorPermissionRepository
import com.example.controlhorario.repository.SupervisorRepository
import com.example.controlhorario.repository.SupervisorWorkScheduleRepository
import com.example.controlhorario.repository.SupervisorEventRepository
import com.example.controlhorario.repository.PendingAttendanceReviewRepository
import com.example.controlhorario.repository.AppUserRepository
import com.example.controlhorario.ui.attendance.AttendanceScreen
import com.example.controlhorario.ui.attendance.AttendanceViewModel
import com.example.controlhorario.ui.attendance.AttendanceViewModelFactory
import com.example.controlhorario.ui.administration.AdministrationSection
import com.example.controlhorario.ui.administration.AdministrationState
import com.example.controlhorario.ui.administration.SystemAdministrationDetailScreen
import com.example.controlhorario.ui.administration.SystemAdministrationScreen
import com.example.controlhorario.ui.administration.SystemAdministrationViewModel
import com.example.controlhorario.ui.administration.SystemAdministrationViewModelFactory
import com.example.controlhorario.ui.biometrics.FingerprintRegistrationScreen
import com.example.controlhorario.ui.biometrics.FingerprintRegistrationViewModel
import com.example.controlhorario.ui.biometrics.FingerprintRegistrationViewModelFactory
import com.example.controlhorario.ui.face.FaceRegistrationScreen
import com.example.controlhorario.ui.face.FaceRegistrationViewModel
import com.example.controlhorario.ui.face.FaceRegistrationViewModelFactory
import com.example.controlhorario.ui.face.FaceVerificationScreen
import com.example.controlhorario.ui.face.FaceVerificationViewModel
import com.example.controlhorario.ui.face.FaceVerificationViewModelFactory
import com.example.controlhorario.ui.branchmanager.BranchManagerScreen
import com.example.controlhorario.ui.branchmanager.BranchManagerViewModel
import com.example.controlhorario.ui.branchmanager.BranchManagerViewModelFactory
import com.example.controlhorario.ui.branches.BranchScreen
import com.example.controlhorario.ui.branches.BranchViewModel
import com.example.controlhorario.ui.branches.BranchViewModelFactory
import com.example.controlhorario.ui.departments.DepartmentScreen
import com.example.controlhorario.ui.departments.DepartmentViewModel
import com.example.controlhorario.ui.departments.DepartmentViewModelFactory
import com.example.controlhorario.ui.employees.AddEmployeeScreen
import com.example.controlhorario.ui.employees.EmployeeListScreen
import com.example.controlhorario.ui.employees.EmployeeProfileScreen
import com.example.controlhorario.ui.employees.EmployeeFileScreen
import com.example.controlhorario.ui.employees.EmployeeDocumentsScreen
import com.example.controlhorario.ui.employees.EmployeeDocumentUploadScreen
import com.example.controlhorario.ui.employees.EmployeeDocumentsViewModel
import com.example.controlhorario.ui.employees.EmployeeDocumentsViewModelFactory
import com.example.controlhorario.ui.employees.EmployeeAttendanceHistoryScreen
import com.example.controlhorario.ui.employees.EmployeePayrollSettingsScreen
import com.example.controlhorario.ui.employees.EmployeePayrollSettingsViewModel
import com.example.controlhorario.ui.employees.EmployeePayrollSettingsViewModelFactory
import com.example.controlhorario.ui.employees.EmployeePayrollPreviewScreen
import com.example.controlhorario.ui.employees.EmployeePayrollHistoryScreen
import com.example.controlhorario.ui.employees.PayrollHistoryViewModel
import com.example.controlhorario.ui.employees.PayrollHistoryViewModelFactory
import com.example.controlhorario.ui.employees.EmployeeViewModel
import com.example.controlhorario.ui.employees.EmployeeViewModelFactory
import com.example.controlhorario.ui.employees.EmployeesScreen
import com.example.controlhorario.ui.employees.EmployeeEditEngine
import com.example.controlhorario.ui.employeepermissions.EmployeePermissionRequestsScreen
import com.example.controlhorario.ui.employeepermissions.EmployeePermissionRequestsViewModel
import com.example.controlhorario.ui.employeepermissions.EmployeePermissionRequestsViewModelFactory
import com.example.controlhorario.ui.login.LoginScreen
import com.example.controlhorario.ui.login.AppUserViewModel
import com.example.controlhorario.ui.login.AppUserViewModelFactory
import com.example.controlhorario.ui.login.PermissionCatalog
import com.example.controlhorario.ui.login.hasPermission
import com.example.controlhorario.ui.loans.LoanViewModel
import com.example.controlhorario.ui.loans.LoanViewModelFactory
import com.example.controlhorario.ui.loans.LoansScreen
import com.example.controlhorario.session.UserSessionManager
import com.example.controlhorario.session.KioskModeManager
import com.example.controlhorario.ui.punch.KioskExitAuthScreen
import com.example.controlhorario.ui.permissions.PermissionsScreen
import com.example.controlhorario.ui.permissions.PermissionsViewModel
import com.example.controlhorario.ui.permissions.PermissionsViewModelFactory
import com.example.controlhorario.ui.payroll.GeneralPayrollScreen
import com.example.controlhorario.ui.payroll.GeneralPayrollViewModel
import com.example.controlhorario.ui.payroll.GeneralPayrollViewModelFactory
import com.example.controlhorario.ui.reports.ReportsScreen
import com.example.controlhorario.ui.punch.EmployeePunchScreen
import com.example.controlhorario.ui.punch.EmployeeVerifiedAttendanceScreen
import com.example.controlhorario.ui.punch.Rc2EmployeeAttendanceScreen
import com.example.controlhorario.ui.punch.JourneyViewModel
import com.example.controlhorario.ui.punch.JourneyViewModelFactory
import com.example.controlhorario.ui.punch.JourneyBiometricGate
import com.example.controlhorario.ui.punch.EmployeePunchViewModel
import com.example.controlhorario.ui.punch.EmployeePunchViewModelFactory
import com.example.controlhorario.ui.settings.CompanyInfoScreen
import com.example.controlhorario.ui.settings.CompanySettingsViewModel
import com.example.controlhorario.ui.settings.CompanySettingsViewModelFactory
import com.example.controlhorario.ui.settings.LaborCalendarScreen
import com.example.controlhorario.ui.settings.LaborCalendarViewModel
import com.example.controlhorario.ui.settings.LaborCalendarViewModelFactory
import com.example.controlhorario.ui.settings.PayrollSettingsScreen
import com.example.controlhorario.ui.settings.PayrollSettingsViewModel
import com.example.controlhorario.ui.settings.PayrollSettingsViewModelFactory
import com.example.controlhorario.ui.settings.WorkScheduleTemplateScreen
import com.example.controlhorario.ui.settings.WorkScheduleTemplateViewModel
import com.example.controlhorario.ui.settings.WorkScheduleTemplateViewModelFactory
import com.example.controlhorario.ui.supervisors.SupervisorAdminScreen
import com.example.controlhorario.ui.supervisors.SupervisorAdminViewModel
import com.example.controlhorario.ui.supervisors.SupervisorAdminViewModelFactory
import com.example.controlhorario.ui.supervisors.SupervisorLoginScreen
import com.example.controlhorario.ui.supervisors.SupervisorHomeScreen
import com.example.controlhorario.ui.supervisors.SupervisorJornadasScreen
import com.example.controlhorario.ui.supervisors.SupervisorEventosScreen
import com.example.controlhorario.ui.supervisors.SupervisorPermisosScreen
import com.example.controlhorario.ui.supervisors.SupervisorAdminOnOffScreen
import com.example.controlhorario.ui.supervisors.SupervisorPanelViewModel
import com.example.controlhorario.ui.supervisors.SupervisorPanelViewModelFactory
import com.example.controlhorario.ui.vacations.VacationViewModel
import com.example.controlhorario.ui.vacations.VacationViewModelFactory
import com.example.controlhorario.ui.incidents.PendingAttendanceReviewScreen
import com.example.controlhorario.ui.incidents.PendingAttendanceReviewViewModel
import com.example.controlhorario.ui.incidents.PendingAttendanceReviewViewModelFactory
import com.example.controlhorario.ui.vacations.VacationsScreen

import com.example.controlhorario.ui.components.OSINETActionCard
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import com.example.controlhorario.ui.components.OSINETTextField
import com.example.controlhorario.ui.components.OSINETLogo
import com.example.controlhorario.ui.components.OSINETNeonEventCard
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.time.LocalDate

@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
) {
    val context=LocalContext.current
    val start=remember{
        when {
            DeviceIdentityManager(context).deviceId == null -> Route.DEVICE_ENROLLMENT
            KioskModeManager.isActive.value -> Route.EMPLOYEE_PUNCH
            UserSessionManager.isLoggedIn() -> "home"
            else -> Route.ADMIN_LOGIN
        }
    }
    NavHost(navController = navController, startDestination = start) {
        composable(Route.DEVICE_ENROLLMENT){DeviceEnrollmentScreen{navController.navigate(Route.ADMIN_LOGIN){popUpTo(Route.DEVICE_ENROLLMENT){inclusive=true}}}}
        composable(Route.ROLE_SELECT) {
            RoleSelectionScreen(
                onAdministrator = { navController.navigate(Route.ADMIN_LOGIN) },
                onSupervisor = { navController.navigate(Route.SUPERVISOR_LOGIN) },
                onEmployee = {
                    navController.navigate(Route.KIOSK_MODE) {
                        popUpTo(Route.ROLE_SELECT) { inclusive = false }
                        launchSingleTop = true
                    }
                }
            )
        }

        composable(Route.KIOSK_MODE) {
            EmployeeKioskScreen(
                onPin = { navController.navigate(Route.EMPLOYEE_PUNCH) },
                onFingerprint = { navController.navigate(Route.EMPLOYEE_PUNCH) },
                onBack = {
                    navController.navigate(Route.KIOSK_EXIT_AUTH) { launchSingleTop = true }
                }
            )
        }

        composable(Route.KIOSK_EXIT_AUTH) {
            val db = DatabaseProvider.getDatabase(LocalContext.current)
            KioskExitAuthScreen(
                repository = AppUserRepository(db.appUserDao()),
                onAuthenticated = { user ->
                    KioskModeManager.deactivate()
                    UserSessionManager.login(user)
                    navController.navigate("home") { popUpTo(0); launchSingleTop = true }
                },
                onCancelled = {
                    navController.navigate(Route.EMPLOYEE_PUNCH) { popUpTo(0); launchSingleTop = true }
                }
            )
        }

        composable(Route.ADMIN_LOGIN) {
            LoginScreen(navController = navController)
        }

        composable(Route.SUPERVISOR_LOGIN) {
            SupervisorLoginScreen(
                onLoggedIn = { supervisorId ->
                    navController.navigate("${Route.SUPERVISOR_HOME}/$supervisorId") {
                        popUpTo(Route.ROLE_SELECT)
                    }
                },
                onBack = {
                    navController.navigate(Route.ROLE_SELECT) {
                        popUpTo(0)
                        launchSingleTop = true
                    }
                }
            )
        }

        composable(
            route = "${Route.SUPERVISOR_HOME}/{supervisorId}",
            arguments = listOf(navArgument("supervisorId") { type = NavType.IntType })
        ) { backStackEntry ->
            val supervisorId = backStackEntry.arguments?.getInt("supervisorId") ?: 0
            SupervisorHomeScreen(
                supervisorId = supervisorId,
                onJornadas = { navController.navigate("${Route.SUPERVISOR_JORNADAS}/$supervisorId") },
                onEventos = { navController.navigate("${Route.SUPERVISOR_EVENTOS}/$supervisorId") },
                onPermisos = { navController.navigate(Route.SUPERVISOR_PERMISOS) },
                onAdminOnOff = { navController.navigate("${Route.SUPERVISOR_ADMIN_ON_OFF}/$supervisorId") },
                onLogout = {
                    navController.navigate(Route.ROLE_SELECT) { popUpTo(0) }
                }
            )
        }

        composable(
            route = "${Route.SUPERVISOR_JORNADAS}/{supervisorId}",
            arguments = listOf(navArgument("supervisorId") { type = NavType.IntType })
        ) { backStackEntry ->
            val supervisorId = backStackEntry.arguments?.getInt("supervisorId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: SupervisorPanelViewModel = viewModel(
                factory = SupervisorPanelViewModelFactory(
                    supervisorId = supervisorId,
                    supervisorRepository = SupervisorRepository(db.supervisorDao()),
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    departmentRepository = DepartmentRepository(db.departmentDao()),
                    attendanceRepository = AttendanceRepository(db.attendanceDao()),
                    scheduleRepository = SupervisorWorkScheduleRepository(db.supervisorWorkScheduleDao()),
                    eventRepository = SupervisorEventRepository(db.supervisorEventDao())
                )
            )
            SupervisorJornadasScreen(vm, onBack = { navController.popBackStack() })
        }

        composable(
            route = "${Route.SUPERVISOR_EVENTOS}/{supervisorId}",
            arguments = listOf(navArgument("supervisorId") { type = NavType.IntType })
        ) { backStackEntry ->
            val supervisorId = backStackEntry.arguments?.getInt("supervisorId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: SupervisorPanelViewModel = viewModel(
                factory = SupervisorPanelViewModelFactory(
                    supervisorId = supervisorId,
                    supervisorRepository = SupervisorRepository(db.supervisorDao()),
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    departmentRepository = DepartmentRepository(db.departmentDao()),
                    attendanceRepository = AttendanceRepository(db.attendanceDao()),
                    scheduleRepository = SupervisorWorkScheduleRepository(db.supervisorWorkScheduleDao()),
                    eventRepository = SupervisorEventRepository(db.supervisorEventDao())
                )
            )
            SupervisorEventosScreen(vm, onBack = { navController.popBackStack() })
        }

        composable(Route.SUPERVISOR_PERMISOS) {
            SupervisorPermisosScreen(onBack = { navController.popBackStack() })
        }

        composable(
            route = "${Route.SUPERVISOR_ADMIN_ON_OFF}/{supervisorId}",
            arguments = listOf(navArgument("supervisorId") { type = NavType.IntType })
        ) { backStackEntry ->
            val supervisorId = backStackEntry.arguments?.getInt("supervisorId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: SupervisorPanelViewModel = viewModel(
                factory = SupervisorPanelViewModelFactory(
                    supervisorId = supervisorId,
                    supervisorRepository = SupervisorRepository(db.supervisorDao()),
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    departmentRepository = DepartmentRepository(db.departmentDao()),
                    attendanceRepository = AttendanceRepository(db.attendanceDao()),
                    scheduleRepository = SupervisorWorkScheduleRepository(db.supervisorWorkScheduleDao()),
                    eventRepository = SupervisorEventRepository(db.supervisorEventDao())
                )
            )
            SupervisorAdminOnOffScreen(vm, onBack = { navController.popBackStack() })
        }

        composable("home") {
            val principal by AuthSessionStore.principal.collectAsState()
            if (principal == null) {
                ModuleScreen("Sesión requerida", "La sesión Supabase no está disponible. Inicia sesión nuevamente.") {
                    UserSessionManager.logout()
                    navController.navigate(Route.ADMIN_LOGIN) { popUpTo(0) }
                }
                return@composable
            }
            val authenticated = principal!!
            val destination = DashboardRoutePolicy.destination(authenticated.roleCode, authenticated.permissionCodes, loading = false)
            val logout = {
                UserSessionManager.logout()
                navController.navigate(Route.ADMIN_LOGIN) { popUpTo(0) }
            }
            if (destination == DashboardDestination.SUPERVISOR_RC3 || destination == DashboardDestination.SUPERVISOR_FALLBACK) {
                val dashboardVm: AndroidDashboardViewModel = viewModel(
                    key = "dashboard-${authenticated.authUid}",
                    factory = AndroidDashboardViewModelFactory(authenticated)
                )
                val dashboardState by dashboardVm.state.collectAsState()
                AuthenticatedSupervisorDashboard(authenticated, dashboardState, logout)
                return@composable
            }
            if(destination==DashboardDestination.EMPLOYEE){
                EmployeeSelfServiceScreen(authenticated){AuthSessionStore.clear();UserSessionManager.logout();navController.navigate(Route.ADMIN_LOGIN){popUpTo(0)}}
                return@composable
            }
            if (destination == DashboardDestination.ERROR) {
                ModuleScreen("Dashboard no disponible", "Rol '${authenticated.roleCode}' sin destino Android válido.", logout)
                return@composable
            }
            AdminHomeScreen(
                onDashboard = { navController.navigate(Route.ADMIN_DASHBOARD) },
                onEmployees = { navController.navigate(Route.EMPLOYEES_MENU) },
                onAttendance = { navController.navigate(Route.ATTENDANCE) },
                onGeneralPayroll = { navController.navigate(Route.GENERAL_PAYROLL) },
                onSupervisors = { navController.navigate(Route.SUPERVISORS_ADMIN) },
                onReports = { navController.navigate(Route.REPORTS_MENU) },
                onSettings = { navController.navigate(Route.SETTINGS_MENU) },
                onVacations = { navController.navigate(Route.VACATIONS_MENU) },
                onLoans = { navController.navigate(Route.LOANS_MENU) },
                onFingerprint = { navController.navigate(Route.FINGERPRINTS) },
                onPermissions = { navController.navigate(Route.PERMISSIONS) },
                onEmployeePermissions = { navController.navigate(Route.EMPLOYEE_PERMISSION_REQUESTS) },
                onIncidents = { navController.navigate(Route.INCIDENTS_CENTER) },
                onEmployeePortal = { navController.navigate(Route.EMPLOYEE_PORTAL) },
                onBranchManager = { navController.navigate(Route.BRANCH_MANAGER_PANEL) },
                onPinMode = {
                    KioskModeManager.activate()
                    UserSessionManager.logout()
                    navController.navigate(Route.EMPLOYEE_PUNCH) { popUpTo(0); launchSingleTop = true }
                },
                onLogout = logout
            )
        }

        composable(Route.ADMIN_DASHBOARD) {
            val principal by AuthSessionStore.principal.collectAsState()
            val authenticated = principal
            if (authenticated == null || authenticated.roleCode != "admin") {
                ModuleScreen("Dashboard no disponible", "Se requiere una sesión administrativa válida.") { navController.popBackStack() }
                return@composable
            }
            val dashboardVm: AndroidDashboardViewModel = viewModel(
                key = "dashboard-${authenticated.authUid}",
                factory = AndroidDashboardViewModelFactory(authenticated)
            )
            val dashboardState by dashboardVm.state.collectAsState()
            OSINETScreen {
                OSINETHeader("Dashboard Administrador", authenticated.fullName)
                Spacer(Modifier.height(16.dp))
                AndroidDashboardPanel(dashboardState)
                Spacer(Modifier.height(18.dp))
                OSINETSecondaryButton("Volver al panel principal", onClick = { navController.popBackStack() })
            }
        }

        composable(Route.USER_PERMISSIONS_ADMIN) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: AppUserViewModel = viewModel(
                factory = AppUserViewModelFactory(AppUserRepository(db.appUserDao()))
            )
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val branchVm: BranchViewModel = viewModel(
                factory = BranchViewModelFactory(BranchRepository(db.branchDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val branches by branchVm.branches.collectAsState()
            UserManagementScreen(
                viewModel = vm,
                employees = employees,
                branches = branches,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.EMPLOYEE_PORTAL) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val currentUser by UserSessionManager.currentUser.collectAsState()
            val vm: EmployeePermissionRequestsViewModel = viewModel(
                factory = EmployeePermissionRequestsViewModelFactory(
                    EmployeePermissionRequestRepository(
                        requestDao = db.employeePermissionRequestDao(),
                        dailyPaymentDao = db.medicalLicenseDailyPaymentDao()
                    )
                )
            )
            EmployeePortalScreen(
                viewModel = vm,
                currentUser = currentUser,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.BRANCH_MANAGER_PANEL) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val currentUser by UserSessionManager.currentUser.collectAsState()
            val branchId = currentUser?.branchId ?: 0
            val vm: BranchManagerViewModel = viewModel(
                factory = BranchManagerViewModelFactory(
                    branchId = branchId,
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    attendanceRepository = AttendanceRepository(db.attendanceDao()),
                    branchRepository = BranchRepository(db.branchDao()),
                    supervisorEventRepository = SupervisorEventRepository(db.supervisorEventDao()),
                    appEventRepository = AppEventRepository(db.appEventDao())
                )
            )
            BranchManagerScreen(
                viewModel = vm,
                onPinMode = {
                    KioskModeManager.activate()
                    UserSessionManager.logout()
                    navController.navigate(Route.EMPLOYEE_PUNCH) { popUpTo(0); launchSingleTop = true }
                },
                onLogout = {
                    UserSessionManager.logout()
                    navController.navigate(Route.ADMIN_LOGIN) { popUpTo(0) }
                }
            )
        }

        composable(Route.EMPLOYEE_PUNCH) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: EmployeePunchViewModel = viewModel(
                factory = EmployeePunchViewModelFactory(
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    faceRepository = EmployeeFaceBiometricRepository(db.employeeFaceBiometricDao())
                )
            )
            EmployeePunchScreen(
                viewModel = vm,
                onVerified = { employeeId ->
                    vm.clear()
                    navController.navigate("${Route.FACE_VERIFICATION}/$employeeId") {
                        launchSingleTop = true
                    }
                },
                onRegisterFace = { employeeId ->
                    if (BuildConfig.DEBUG) Log.d("FACE_REG_NAV_START", "employeeId=$employeeId")
                    vm.clear()
                    navController.navigate("${Route.FACE_KIOSK_REGISTRATION}/$employeeId") {
                        launchSingleTop = true
                    }
                },
                onBack = {
                    navController.navigate(Route.ROLE_SELECT) {
                        popUpTo(0)
                        launchSingleTop = true
                    }
                }
            )
        }

        composable(
            route = "${Route.FACE_VERIFICATION}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: FaceVerificationViewModel = viewModel(
                factory = FaceVerificationViewModelFactory(
                    employeeId = employeeId,
                    faces = EmployeeFaceBiometricRepository(db.employeeFaceBiometricDao())
                )
            )
            FaceVerificationScreen(
                viewModel = vm,
                onRecognized = {
                    val deviceId = DeviceIdentityManager(context).deviceId
                    if (deviceId == null) {
                        if (BuildConfig.DEBUG) Log.d("PUNCH_AUTH", "employeeId=$employeeId faceVerified=true authorizationIssued=false reason=device_not_enrolled")
                        navController.popBackStack(Route.EMPLOYEE_PUNCH, false)
                        return@FaceVerificationScreen
                    }
                    JourneyBiometricGate.open(employeeId, deviceId)
                    if (BuildConfig.DEBUG) Log.d("PUNCH_AUTH", "employeeId=$employeeId pinVerified=true faceVerified=true authorizedEmployeeId=$employeeId authorizationConsumed=false isPunchAuthorized=true")
                    navController.navigate("${Route.EMPLOYEE_ASSISTANCE}/$employeeId") {
                        popUpTo(Route.FACE_VERIFICATION) { inclusive = true }
                    }
                },
                onCancel = {
                    navController.popBackStack(Route.EMPLOYEE_PUNCH, false)
                }
            )
        }

        composable(
            route = "${Route.FACE_KIOSK_REGISTRATION}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: FaceRegistrationViewModel = viewModel(
                factory = FaceRegistrationViewModelFactory(
                    EmployeeRepository(db.employeeDao()),
                    EmployeeFaceBiometricRepository(db.employeeFaceBiometricDao())
                )
            )
            FaceRegistrationScreen(
                viewModel = vm,
                initialEmployeeId = employeeId,
                onRegistered = { employeeId ->
                    navController.navigate("${Route.FACE_VERIFICATION}/$employeeId") {
                        popUpTo(Route.FACE_KIOSK_REGISTRATION) { inclusive = true }
                    }
                },
                onBack = { navController.popBackStack(Route.EMPLOYEE_PUNCH, false) }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_ASSISTANCE}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val journeyVm: JourneyViewModel = viewModel(
                factory = JourneyViewModelFactory(context,JourneyRepository(db.journeyDao()),employeeId,LocalDate.now().toString())
            )
            val employees by employeeVm.employees.collectAsState()
            val employee = employees.firstOrNull { it.id == employeeId }
            Rc2EmployeeAttendanceScreen(
                employee = employee,
                viewModel = journeyVm,
                onFinish = {
                    JourneyBiometricGate.clear()
                    navController.navigate(Route.EMPLOYEE_PUNCH) {
                        popUpTo(0)
                        launchSingleTop = true
                    }
                }
            )
        }

        composable(Route.EMPLOYEES_MENU) {
            EmployeesScreen(
                onAddEmployeeClick = { navController.navigate(Route.EMPLOYEE_ADD) },
                onEmployeeListClick = { navController.navigate(Route.EMPLOYEE_LIST) },
                onSyncedEmployeesClick = { navController.navigate(Route.EMPLOYEE_SYNC_DASHBOARD) },
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.EMPLOYEE_SYNC_DASHBOARD) {
            val db = DatabaseProvider.getDatabase(LocalContext.current)
            val vm: EmployeeSyncDashboardViewModel = viewModel(factory = EmployeeSyncDashboardViewModelFactory(db.employeeDao(),db.deviceEnrollmentDao()))
            EmployeeSyncDashboardScreen(vm,onSync={DeviceSyncScheduler.start(context)},onBack={navController.popBackStack()})
        }

        composable(Route.EMPLOYEE_ADD) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val branchVm: BranchViewModel = viewModel(
                factory = BranchViewModelFactory(BranchRepository(db.branchDao()))
            )
            val departmentVm: DepartmentViewModel = viewModel(
                factory = DepartmentViewModelFactory(DepartmentRepository(db.departmentDao()))
            )
            val branches by branchVm.branches.collectAsState()
            val departments by departmentVm.departments.collectAsState()
            AddEmployeeScreen(
                viewModel = vm,
                branches = branches,
                departments = departments,
                onRegisterFingerprint = { code -> navController.navigate("${Route.FINGERPRINTS}/$code") },
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_EDIT}/{employeeKey}",
            arguments = listOf(navArgument("employeeKey") { type = NavType.StringType })
        ) { backStackEntry ->
            val employeeKey = backStackEntry.arguments?.getString("employeeKey").orEmpty()
            val db = DatabaseProvider.getDatabase(LocalContext.current)
            val vm: EmployeeViewModel = viewModel(factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao())))
            val branchVm: BranchViewModel = viewModel(factory = BranchViewModelFactory(BranchRepository(db.branchDao())))
            val departmentVm: DepartmentViewModel = viewModel(factory = DepartmentViewModelFactory(DepartmentRepository(db.departmentDao())))
            val employee by vm.editingEmployee.collectAsState()
            val branches by branchVm.branches.collectAsState()
            val departments by departmentVm.departments.collectAsState()
            LaunchedEffect(employeeKey) { vm.loadEmployeeForEdit(employeeKey) }
            employee?.let {
                AddEmployeeScreen(
                    viewModel=vm,branches=branches,departments=departments,initialEmployee=it,isEditMode=true,
                    onRegisterFingerprint={code->navController.navigate("${Route.FINGERPRINTS}/$code")},
                    onSaved={navController.popBackStack()},onBack={navController.popBackStack()}
                )
            } ?: Text("Cargando empleado…")
        }

        composable(Route.EMPLOYEE_LIST) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            EmployeeListScreen(
                viewModel = vm,
                onEmployeeClick = { employeeId -> navController.navigate("${Route.EMPLOYEE_PROFILE}/$employeeId") },
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_PROFILE}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val branchVm: BranchViewModel = viewModel(
                factory = BranchViewModelFactory(BranchRepository(db.branchDao()))
            )
            val departmentVm: DepartmentViewModel = viewModel(
                factory = DepartmentViewModelFactory(DepartmentRepository(db.departmentDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val branches by branchVm.branches.collectAsState()
            val departments by departmentVm.departments.collectAsState()
            val employee = employees.firstOrNull { it.id == employeeId }
            EmployeeProfileScreen(
                employee = employee,
                branches = branches,
                departments = departments,
                onEmployeeFileClick = { navController.navigate("${Route.EMPLOYEE_FILE}/$employeeId") },
                onAttendanceHistoryClick = { navController.navigate("${Route.EMPLOYEE_ATTENDANCE_HISTORY}/$employeeId") },
                onEmployeePayrollSettingsClick = { navController.navigate("${Route.EMPLOYEE_PAYROLL_SETTINGS}/$employeeId") },
                onPayrollPreviewClick = { navController.navigate("${Route.EMPLOYEE_PAYROLL_PREVIEW}/$employeeId") },
                onPayrollHistoryClick = { navController.navigate("${Route.EMPLOYEE_PAYROLL_HISTORY}/$employeeId") },
                onFingerprintClick = {
                    val code = employee?.employeeCode?.ifBlank { employee.pin } ?: employeeId.toString().padStart(5, '0')
                    navController.navigate("${Route.FINGERPRINTS}/$code")
                },
                onEditEmployeeClick = {
                    val employeeKey=employee?.let(EmployeeEditEngine::routeKey)?:employeeId.toString()
                    navController.navigate("${Route.EMPLOYEE_EDIT}/$employeeKey")
                },
                onPermissionsClick = { navController.navigate(Route.PERMISSIONS) },
                onWarningsClick = { navController.navigate(Route.REPORTS_MENU) },
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_FILE}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val employee = employees.firstOrNull { it.id == employeeId }
            EmployeeFileScreen(
                employee = employee,
                onGeneralInfoClick = { navController.navigate("${Route.EMPLOYEE_PROFILE}/$employeeId") },
                onDocumentsClick = { navController.navigate("${Route.EMPLOYEE_DOCUMENTS}/$employeeId") },
                onAttendanceClick = { navController.navigate("${Route.EMPLOYEE_ATTENDANCE_HISTORY}/$employeeId") },
                onPayrollClick = { navController.navigate("${Route.EMPLOYEE_PAYROLL_PREVIEW}/$employeeId") },
                onCreditsClick = { navController.navigate("${Route.EMPLOYEE_PAYROLL_SETTINGS}/$employeeId") },
                onPermissionsClick = { navController.navigate(Route.PERMISSIONS) },
                onWarningsClick = { navController.navigate(Route.REPORTS_MENU) },
                onTrainingsClick = { navController.navigate(Route.REPORTS_MENU) },
                onEvaluationsClick = { navController.navigate(Route.REPORTS_MENU) },
                onCertificatesClick = { navController.navigate("${Route.EMPLOYEE_DOCUMENTS}/$employeeId") },
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_DOCUMENTS}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val docsVm: EmployeeDocumentsViewModel = viewModel(
                factory = EmployeeDocumentsViewModelFactory(EmployeeDocumentRepository(db.employeeDocumentDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val employee = employees.firstOrNull { it.id == employeeId }
            EmployeeDocumentsScreen(
                employee = employee,
                viewModel = docsVm,
                onUploadDocument = { navController.navigate("${Route.EMPLOYEE_DOCUMENT_UPLOAD}/$employeeId") },
                onPreviewDocument = { documentId -> docsVm.markDocumentAction(documentId, "Vista previa registrada localmente") },
                onShareDocument = { documentId -> docsVm.markDocumentAction(documentId, "Documento marcado para compartir") },
                onDeleteDocument = { documentId -> docsVm.deactivateDocument(documentId) },
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_DOCUMENT_UPLOAD}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val docsVm: EmployeeDocumentsViewModel = viewModel(
                factory = EmployeeDocumentsViewModelFactory(EmployeeDocumentRepository(db.employeeDocumentDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val employee = employees.firstOrNull { it.id == employeeId }
            EmployeeDocumentUploadScreen(
                employee = employee,
                viewModel = docsVm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_ATTENDANCE_HISTORY}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val attendanceVm: AttendanceViewModel = viewModel(
                factory = AttendanceViewModelFactory(AttendanceRepository(db.attendanceDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val records by attendanceVm.attendanceRecords.collectAsState()
            EmployeeAttendanceHistoryScreen(
                employee = employees.firstOrNull { it.id == employeeId },
                attendanceRecords = records,
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_PAYROLL_SETTINGS}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val payrollVm: EmployeePayrollSettingsViewModel = viewModel(
                factory = EmployeePayrollSettingsViewModelFactory(EmployeePayrollSettingsRepository(db.employeePayrollSettingsDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            EmployeePayrollSettingsScreen(
                employee = employees.firstOrNull { it.id == employeeId },
                viewModel = payrollVm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_PAYROLL_HISTORY}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val historyVm: PayrollHistoryViewModel = viewModel(
                factory = PayrollHistoryViewModelFactory(PayrollHistoryRepository(db.payrollHistoryDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            EmployeePayrollHistoryScreen(
                employee = employees.firstOrNull { it.id == employeeId },
                viewModel = historyVm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            route = "${Route.EMPLOYEE_PAYROLL_PREVIEW}/{employeeId}",
            arguments = listOf(navArgument("employeeId") { type = NavType.IntType })
        ) { backStackEntry ->
            val employeeId = backStackEntry.arguments?.getInt("employeeId") ?: 0
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val attendanceVm: AttendanceViewModel = viewModel(
                factory = AttendanceViewModelFactory(AttendanceRepository(db.attendanceDao()))
            )
            val laborVm: LaborCalendarViewModel = viewModel(
                factory = LaborCalendarViewModelFactory(LaborCalendarRepository(db.laborCalendarDayDao()))
            )
            val payrollSettingsVm: PayrollSettingsViewModel = viewModel(
                factory = PayrollSettingsViewModelFactory(PayrollSettingsRepository(db.payrollSettingsDao()))
            )
            val companyVm: CompanySettingsViewModel = viewModel(
                factory = CompanySettingsViewModelFactory(CompanySettingsRepository(db.companySettingsDao()))
            )
            val employeePayrollVm: EmployeePayrollSettingsViewModel = viewModel(
                factory = EmployeePayrollSettingsViewModelFactory(EmployeePayrollSettingsRepository(db.employeePayrollSettingsDao()))
            )
            val historyVm: PayrollHistoryViewModel = viewModel(
                factory = PayrollHistoryViewModelFactory(PayrollHistoryRepository(db.payrollHistoryDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val attendance by attendanceVm.attendanceRecords.collectAsState()
            val laborDays by laborVm.laborCalendarDays.collectAsState()
            val payrollSettings by payrollSettingsVm.payrollSettings.collectAsState()
            val companySettings by companyVm.companySettings.collectAsState()
            EmployeePayrollPreviewScreen(
                employee = employees.firstOrNull { it.id == employeeId },
                attendanceRecords = attendance,
                laborCalendarDays = laborDays,
                generalSettings = payrollSettings,
                companySettings = companySettings,
                employeePayrollSettingsViewModel = employeePayrollVm,
                payrollHistoryViewModel = historyVm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.ATTENDANCE) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val attendanceVm: AttendanceViewModel = viewModel(
                factory = AttendanceViewModelFactory(AttendanceRepository(db.attendanceDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            AttendanceScreen(
                employees = employees,
                viewModel = attendanceVm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.FINGERPRINTS) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: FaceRegistrationViewModel = viewModel(factory = FaceRegistrationViewModelFactory(EmployeeRepository(db.employeeDao()), EmployeeFaceBiometricRepository(db.employeeFaceBiometricDao())))
            FaceRegistrationScreen(viewModel = vm, onBack = { navController.popBackStack() })
        }

        composable(
            route = "${Route.FINGERPRINTS}/{employeeCode}",
            arguments = listOf(navArgument("employeeCode") { type = NavType.StringType })
        ) { backStackEntry ->
            val employeeCode = backStackEntry.arguments?.getString("employeeCode").orEmpty()
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: FaceRegistrationViewModel = viewModel(factory = FaceRegistrationViewModelFactory(EmployeeRepository(db.employeeDao()), EmployeeFaceBiometricRepository(db.employeeFaceBiometricDao())))
            FaceRegistrationScreen(viewModel = vm, onBack = { navController.popBackStack() }, initialEmployeeCode = employeeCode)
        }

        composable(Route.PERMISSIONS) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: PermissionsViewModel = viewModel(
                factory = PermissionsViewModelFactory(SupervisorPermissionRepository(db.supervisorPermissionDao()))
            )
            PermissionsScreen(vm) { navController.popBackStack() }
        }

        composable(Route.EMPLOYEE_PERMISSION_REQUESTS) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val currentUser by UserSessionManager.currentUser.collectAsState()
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val vm: EmployeePermissionRequestsViewModel = viewModel(
                factory = EmployeePermissionRequestsViewModelFactory(
                    EmployeePermissionRequestRepository(
                        requestDao = db.employeePermissionRequestDao(),
                        dailyPaymentDao = db.medicalLicenseDailyPaymentDao()
                    )
                )
            )
            EmployeePermissionRequestsScreen(
                viewModel = vm,
                employees = employees,
                reviewerName = currentUser?.fullName ?: "ADMIN",
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.GENERAL_PAYROLL) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: GeneralPayrollViewModel = viewModel(
                factory = GeneralPayrollViewModelFactory(
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    attendanceRepository = AttendanceRepository(db.attendanceDao()),
                    laborCalendarRepository = LaborCalendarRepository(db.laborCalendarDayDao()),
                    payrollSettingsRepository = PayrollSettingsRepository(db.payrollSettingsDao()),
                    employeePayrollSettingsRepository = EmployeePayrollSettingsRepository(db.employeePayrollSettingsDao()),
                    employeePermissionRequestRepository = EmployeePermissionRequestRepository(
                        requestDao = db.employeePermissionRequestDao(),
                        dailyPaymentDao = db.medicalLicenseDailyPaymentDao()
                    ),
                    companySettingsRepository = CompanySettingsRepository(db.companySettingsDao())
                )
            )
            GeneralPayrollScreen(
                viewModel = vm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.SUPERVISORS_ADMIN) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: SupervisorAdminViewModel = viewModel(
                factory = SupervisorAdminViewModelFactory(
                    supervisorRepository = SupervisorRepository(db.supervisorDao()),
                    branchRepository = BranchRepository(db.branchDao()),
                    departmentRepository = DepartmentRepository(db.departmentDao())
                )
            )
            SupervisorAdminScreen(vm, onBack = { navController.popBackStack() })
        }

        composable(Route.SETTINGS_MENU) {
            SystemAdministrationRoute(
                onSection = { section ->
                    navController.navigate(
                        when (section) {
                            AdministrationSection.COMPANY -> Route.ADMIN_EMPRESA
                            AdministrationSection.BRANCHES -> Route.ADMIN_SUCURSALES
                            AdministrationSection.DEPARTMENTS -> Route.ADMIN_DEPARTAMENTOS
                            AdministrationSection.POSITIONS -> Route.ADMIN_CARGOS
                            AdministrationSection.USERS -> Route.ADMIN_USUARIOS
                            AdministrationSection.SCHEDULES -> Route.ADMIN_HORARIOS
                            AdministrationSection.JOURNEYS -> Route.ADMIN_JORNADAS
                            AdministrationSection.DEVICES -> Route.ADMIN_DISPOSITIVOS
                            AdministrationSection.SECURITY -> Route.ADMIN_SEGURIDAD
                            AdministrationSection.APPEARANCE -> Route.ADMIN_APARIENCIA
                        }
                    )
                },
                onBack = { navController.popBackStack() },
            )
        }

        composable(Route.ADMIN_EMPRESA) { SystemAdministrationDetailRoute(AdministrationSection.COMPANY) { navController.popBackStack() } }
        composable(Route.ADMIN_SUCURSALES) { SystemAdministrationDetailRoute(AdministrationSection.BRANCHES) { navController.popBackStack() } }
        composable(Route.ADMIN_DEPARTAMENTOS) { SystemAdministrationDetailRoute(AdministrationSection.DEPARTMENTS) { navController.popBackStack() } }
        composable(Route.ADMIN_CARGOS) { SystemAdministrationDetailRoute(AdministrationSection.POSITIONS) { navController.popBackStack() } }
        composable(Route.ADMIN_USUARIOS) { SystemAdministrationDetailRoute(AdministrationSection.USERS) { navController.popBackStack() } }
        composable(Route.ADMIN_HORARIOS) { SystemAdministrationDetailRoute(AdministrationSection.SCHEDULES) { navController.popBackStack() } }
        composable(Route.ADMIN_JORNADAS) { SystemAdministrationDetailRoute(AdministrationSection.JOURNEYS) { navController.popBackStack() } }
        composable(Route.ADMIN_DISPOSITIVOS) { SystemAdministrationDetailRoute(AdministrationSection.DEVICES) { navController.popBackStack() } }
        composable(Route.ADMIN_SEGURIDAD) { SystemAdministrationDetailRoute(AdministrationSection.SECURITY) { navController.popBackStack() } }
        composable(Route.ADMIN_APARIENCIA) { SystemAdministrationDetailRoute(AdministrationSection.APPEARANCE) { navController.popBackStack() } }

        composable(Route.BRANCHES) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: BranchViewModel = viewModel(
                factory = BranchViewModelFactory(BranchRepository(db.branchDao()))
            )
            BranchScreen(vm) { navController.popBackStack() }
        }

        composable(Route.DEPARTMENTS) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: DepartmentViewModel = viewModel(
                factory = DepartmentViewModelFactory(DepartmentRepository(db.departmentDao()))
            )
            val branchVm: BranchViewModel = viewModel(
                factory = BranchViewModelFactory(BranchRepository(db.branchDao()))
            )
            val userVm: AppUserViewModel = viewModel(
                factory = AppUserViewModelFactory(AppUserRepository(db.appUserDao()))
            )
            val branches by branchVm.branches.collectAsState()
            val users by userVm.users.collectAsState(initial = emptyList())
            DepartmentScreen(
                branches = branches,
                users = users,
                viewModel = vm,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.PAYROLL_MENU) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: PayrollSettingsViewModel = viewModel(
                factory = PayrollSettingsViewModelFactory(PayrollSettingsRepository(db.payrollSettingsDao()))
            )
            PayrollSettingsScreen(vm) { navController.popBackStack() }
        }
        composable(Route.REPORTS_MENU) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val attendanceVm: AttendanceViewModel = viewModel(
                factory = AttendanceViewModelFactory(AttendanceRepository(db.attendanceDao()))
            )
            val vacationVm: VacationViewModel = viewModel(
                factory = VacationViewModelFactory(VacationRepository(db.vacationDao()))
            )
            val permissionsVm: PermissionsViewModel = viewModel(
                factory = PermissionsViewModelFactory(SupervisorPermissionRepository(db.supervisorPermissionDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            val attendance by attendanceVm.attendanceRecords.collectAsState()
            val vacations by vacationVm.vacations.collectAsState()
            val permissions by permissionsVm.permissions.collectAsState()
            ReportsScreen(
                employees = employees,
                attendance = attendance,
                vacations = vacations,
                permissions = permissions,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.VACATIONS_MENU) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vacationVm: VacationViewModel = viewModel(
                factory = VacationViewModelFactory(VacationRepository(db.vacationDao()))
            )
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            VacationsScreen(
                viewModel = vacationVm,
                employees = employees,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.LOANS_MENU) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val loanVm: LoanViewModel = viewModel(
                factory = LoanViewModelFactory(LoanRepository(db.loanDao()))
            )
            val employeeVm: EmployeeViewModel = viewModel(
                factory = EmployeeViewModelFactory(EmployeeRepository(db.employeeDao()))
            )
            val employees by employeeVm.employees.collectAsState()
            LoansScreen(
                viewModel = loanVm,
                employees = employees,
                onBack = { navController.popBackStack() }
            )
        }

        composable(Route.INCIDENTS_CENTER) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: PendingAttendanceReviewViewModel = viewModel(
                factory = PendingAttendanceReviewViewModelFactory(
                    reviewRepository = PendingAttendanceReviewRepository(db.pendingAttendanceReviewDao()),
                    employeeRepository = EmployeeRepository(db.employeeDao()),
                    attendanceRepository = AttendanceRepository(db.attendanceDao())
                )
            )
            PendingAttendanceReviewScreen(vm, onBack = { navController.popBackStack() })
        }

        composable(Route.COMPANY_SETTINGS) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: CompanySettingsViewModel = viewModel(
                factory = CompanySettingsViewModelFactory(CompanySettingsRepository(db.companySettingsDao()))
            )
            CompanyInfoScreen(vm) { navController.popBackStack() }
        }

        composable(Route.WORK_SCHEDULE) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: WorkScheduleTemplateViewModel = viewModel(
                factory = WorkScheduleTemplateViewModelFactory(WorkScheduleTemplateRepository(db.workScheduleTemplateDao()))
            )
            WorkScheduleTemplateScreen(vm) { navController.popBackStack() }
        }

        composable(Route.PAYROLL_SETTINGS) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: PayrollSettingsViewModel = viewModel(
                factory = PayrollSettingsViewModelFactory(PayrollSettingsRepository(db.payrollSettingsDao()))
            )
            PayrollSettingsScreen(vm) { navController.popBackStack() }
        }

        composable(Route.LABOR_CALENDAR) {
            val context = LocalContext.current
            val db = DatabaseProvider.getDatabase(context)
            val vm: LaborCalendarViewModel = viewModel(
                factory = LaborCalendarViewModelFactory(LaborCalendarRepository(db.laborCalendarDayDao()))
            )
            LaborCalendarScreen(vm) { navController.popBackStack() }
        }
    }
}

@Composable
private fun RoleSelectionScreen(
    onAdministrator: () -> Unit,
    onSupervisor: () -> Unit,
    onEmployee: () -> Unit
) {
    OSINETScreen {
        androidx.compose.foundation.layout.Column {
            Spacer(Modifier.height(28.dp))
            OSINETHeader(
                title = "Selección de acceso",
                subtitle = "Elige el tipo de acceso para continuar"
            )
            Spacer(Modifier.height(34.dp))
            OSINETActionCard(
                title = "Empleado",
                subtitle = "Registrar mi jornada",
                onClick = onEmployee
            )
            Spacer(Modifier.height(14.dp))
            OSINETActionCard(
                title = "Supervisor",
                subtitle = "Acceder al panel operativo",
                onClick = onSupervisor
            )
            Spacer(Modifier.height(14.dp))
            OSINETActionCard(
                title = "Administrador",
                subtitle = "Acceso total al ERP",
                onClick = onAdministrator
            )
        }
    }
}

@Composable
private fun EmployeeKioskScreen(
    onPin: () -> Unit,
    onFingerprint: () -> Unit,
    onBack: () -> Unit
) {
    OSINETScreen {
        OSINETHeader(
            title = "Modo Kiosko",
            subtitle = "Seleccione cómo registrar la jornada"
        )
        Spacer(Modifier.height(28.dp))
        OSINETActionCard(
            title = "PIN",
            subtitle = "Ingresar código de empleado y validar rostro",
            onClick = onPin
        )
        Spacer(Modifier.height(14.dp))
        OSINETActionCard(
            title = "ROSTRO",
            subtitle = "Abrir registro de jornada con validación biométrica",
            onClick = onFingerprint
        )
        Spacer(Modifier.height(22.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun AdminHomeScreen(
    onDashboard: () -> Unit,
    onEmployees: () -> Unit,
    onAttendance: () -> Unit,
    onGeneralPayroll: () -> Unit,
    onSupervisors: () -> Unit,
    onReports: () -> Unit,
    onSettings: () -> Unit,
    onVacations: () -> Unit,
    onLoans: () -> Unit,
    onFingerprint: () -> Unit,
    onPermissions: () -> Unit,
    onEmployeePermissions: () -> Unit,
    onIncidents: () -> Unit,
    onEmployeePortal: () -> Unit,
    onBranchManager: () -> Unit,
    onPinMode: () -> Unit,
    onLogout: () -> Unit
) {
    val sessionUser by UserSessionManager.currentUser.collectAsState()
    val permissionCsv = sessionUser?.permissionsCsv.orEmpty()
    var permissionsEventOpened by remember { mutableStateOf(false) }
    var portalEventOpened by remember { mutableStateOf(false) }
    fun can(permission: String): Boolean = permissionCsv.isBlank() || permissionCsv.hasPermission(permission)

    OSINETScreen {
        OSINETLogo(subtitle = "Panel Administrador · Menú por permisos")
        Spacer(Modifier.height(16.dp))
        if (can(PermissionCatalog.DASHBOARD)) { OSINETActionCard("Dashboard", "Métricas operativas y jornadas recientes", onClick = onDashboard); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.EMPLOYEES)) { OSINETActionCard("Empleados", "Gestión de perfiles, rostros y datos laborales", onClick = onEmployees); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.ATTENDANCE)) { OSINETActionCard("Asistencia", "Registros y control diario", onClick = onAttendance); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.PIN_MODE)) { OSINETActionCard("Activar modo PIN", "Abrir ponchador para empleados", onClick = onPinMode); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.INCIDENTS)) { OSINETActionCard("Centro de Incidencias", "Jornadas pendientes y eventos nuevos", onClick = onIncidents); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.BRANCH_MANAGER)) { OSINETActionCard("Panel Encargado", "Eventos y empleados de mi sucursal", onClick = onBranchManager); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.PAYROLL)) { OSINETActionCard("GENERAL NÓMINA", "Generación, plantillas y exportación", onClick = onGeneralPayroll); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.REPORTS)) { OSINETActionCard("Reportes", "Consultas generales del sistema", onClick = onReports); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.SETTINGS)) { OSINETActionCard("Administración del sistema", "Empresa, organización, usuarios, seguridad y apariencia", onClick = onSettings); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.ATTENDANCE)) { OSINETActionCard("Vacaciones", "Solicitudes y seguimiento", onClick = onVacations); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.LOANS)) { OSINETActionCard("Préstamos", "Solicitudes, aprobación, entrega y balance", onClick = onLoans); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.EMPLOYEE_PERMISSION_REQUESTS)) { OSINETActionCard("Permisos Empleados", "Solicitudes, archivos, aprobación y rechazo", onClick = onEmployeePermissions); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.EMPLOYEES)) { OSINETActionCard("Registro facial", "Registrar rostro", onClick = onFingerprint); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.PIN_MODE)) { OSINETActionCard("Permisos Supervisores", "Solicitudes preparadas para aprobación", onClick = onPermissions); Spacer(Modifier.height(10.dp)) }
        if (can(PermissionCatalog.EMPLOYEE_PORTAL)) { OSINETNeonEventCard("Portal del Empleado", "Pagos, préstamos, historial y solicitudes", isNew = !portalEventOpened, onOpen = { portalEventOpened = true; onEmployeePortal() }); Spacer(Modifier.height(10.dp)) }
        Spacer(Modifier.height(8.dp))
        OSINETSecondaryButton("Cerrar sesión", onLogout)
    }
}

@Composable
private fun SystemAdministrationRoute(
    onSection: (AdministrationSection) -> Unit,
    onBack: () -> Unit,
) {
    val principal by AuthSessionStore.principal.collectAsState()
    val current = principal
    if (current == null) {
        SystemAdministrationScreen(
            state = AdministrationState.Error("La sesión administrativa no está disponible."),
            onSection = onSection,
            onBack = onBack,
        )
        return
    }
    val vm: SystemAdministrationViewModel = viewModel(
        key = "system-administration-${current.authUid}",
        factory = SystemAdministrationViewModelFactory(current),
    )
    val state by vm.state.collectAsState()
    SystemAdministrationScreen(state = state, onSection = onSection, onBack = onBack)
}

@Composable
private fun SystemAdministrationDetailRoute(
    section: AdministrationSection,
    onBack: () -> Unit,
) {
    val principal by AuthSessionStore.principal.collectAsState()
    val current = principal
    if (current == null) {
        SystemAdministrationDetailScreen(
            section = section,
            state = AdministrationState.Error("La sesión administrativa no está disponible."),
            onBack = onBack,
        )
        return
    }
    val vm: SystemAdministrationViewModel = viewModel(
        key = "system-administration-${current.authUid}",
        factory = SystemAdministrationViewModelFactory(current),
    )
    val state by vm.state.collectAsState()
    SystemAdministrationDetailScreen(section = section, state = state, onBack = onBack)
}



@Composable
private fun UserManagementScreen(
    viewModel: AppUserViewModel,
    employees: List<com.example.controlhorario.model.Employee>,
    branches: List<com.example.controlhorario.database.BranchEntity>,
    onBack: () -> Unit
) {
    val users by viewModel.users.collectAsState(initial = emptyList())
    var fullName by remember { mutableStateOf("") }
    var username by remember { mutableStateOf("") }
    var email by remember { mutableStateOf("") }
    var password by remember { mutableStateOf("") }
    var role by remember { mutableStateOf("EMPLEADO") }
    var employeeSearch by remember { mutableStateOf("") }
    var selectedEmployeeId by remember { mutableStateOf(0) }
    var selectedBranchId by remember { mutableStateOf(0) }
    var message by remember { mutableStateOf("") }
    var selectedPermissions by remember { mutableStateOf(setOf<String>()) }

    val filteredEmployees = employees
        .filter { employee ->
            val q = employeeSearch.trim()
            q.isBlank() ||
                employee.employeeCode.contains(q, ignoreCase = true) ||
                employee.pin.contains(q, ignoreCase = true) ||
                employee.nombre.contains(q, ignoreCase = true)
        }
        .sortedBy { it.employeeCode.padStart(8, '0') }
        .take(8)

    fun setRole(newRole: String) {
        role = newRole
        selectedPermissions = when (newRole) {
            "ADMINISTRADOR" -> PermissionCatalog.all.toSet()
            "SUPERVISOR" -> setOf(PermissionCatalog.ATTENDANCE, PermissionCatalog.INCIDENTS, PermissionCatalog.PIN_MODE, PermissionCatalog.EMPLOYEE_PERMISSION_REQUESTS)
            "ENCARGADO" -> setOf(PermissionCatalog.BRANCH_MANAGER, PermissionCatalog.ATTENDANCE, PermissionCatalog.ATTENDANCE_DASHBOARD, PermissionCatalog.INCIDENTS, PermissionCatalog.PIN_MODE, PermissionCatalog.REPORTS, PermissionCatalog.EMPLOYEE_PERMISSION_REQUESTS)
            "ASISTENTE" -> setOf(PermissionCatalog.EMPLOYEES, PermissionCatalog.REPORTS)
            else -> setOf(PermissionCatalog.EMPLOYEE_PORTAL)
        }
    }

    OSINETScreen {
        OSINETHeader(
            title = "Usuarios",
            subtitle = "Crear usuarios y asignar permisos por módulo"
        )
        Spacer(Modifier.height(14.dp))
        OSINETCard {
            Text("Crear usuario", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
            Spacer(Modifier.height(8.dp))
            OSINETTextField(fullName, { fullName = it }, "Nombre completo", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(username, { username = it }, "Usuario", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(email, { email = it }, "Correo de acceso", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            OSINETTextField(password, { password = it }, "Contraseña", Modifier.fillMaxWidth())
            Spacer(Modifier.height(10.dp))
            OSINETActionCard("Administrador", "Acceso total", onClick = { setRole("ADMINISTRADOR") })
            Spacer(Modifier.height(6.dp))
            OSINETActionCard("Supervisor", "Operación por departamentos", onClick = { setRole("SUPERVISOR") })
            Spacer(Modifier.height(6.dp))
            OSINETActionCard("Encargado", "Eventos y empleados de una sucursal, sin nómina", onClick = { setRole("ENCARGADO") })
            Spacer(Modifier.height(6.dp))
            OSINETActionCard("Asistente", "Permisos configurables", onClick = { setRole("ASISTENTE") })
            Spacer(Modifier.height(6.dp))
            OSINETActionCard("Empleado", "Portal del empleado", onClick = { setRole("EMPLEADO") })
            Spacer(Modifier.height(8.dp))
            Text("Rol seleccionado: $role", color = com.example.controlhorario.ui.components.OSINETColors.GreenSoft)
        }
        Spacer(Modifier.height(12.dp))
        if (role == "ENCARGADO") {
            OSINETCard {
                Text("Sucursal del encargado", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                Text("El encargado solo verá eventos y empleados de la sucursal seleccionada. No recibe permisos de nómina.", color = com.example.controlhorario.ui.components.OSINETColors.TextSecondary)
                Spacer(Modifier.height(8.dp))
                branches.forEach { branch ->
                    OSINETActionCard(
                        title = branch.name,
                        subtitle = "${branch.code} · ${if (selectedBranchId == branch.id) "Seleccionada" else "Tocar para asignar"}",
                        onClick = { selectedBranchId = branch.id }
                    )
                    Spacer(Modifier.height(6.dp))
                }
            }
            Spacer(Modifier.height(12.dp))
        }
        OSINETCard {
            Text("Asignar empleado registrado", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
            Text("La búsqueda interna permite código, PIN o nombre. El ponchador usa PIN + rostro.", color = com.example.controlhorario.ui.components.OSINETColors.TextSecondary)
            Spacer(Modifier.height(8.dp))
            OSINETTextField(employeeSearch, { employeeSearch = it }, "Buscar empleado por código, PIN o nombre", Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))
            filteredEmployees.forEach { employee ->
                OSINETActionCard(
                    title = "${employee.employeeCode.ifBlank { employee.pin }} · ${employee.nombre}",
                    subtitle = "${employee.departamento} · ${if (selectedEmployeeId == employee.id) "Seleccionado" else "Tocar para asignar"}",
                    onClick = { selectedEmployeeId = employee.id; email = employee.email.trim().lowercase() }
                )
                Spacer(Modifier.height(6.dp))
            }
        }
        Spacer(Modifier.height(12.dp))
        OSINETCard {
            Text("Permisos por módulo", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
            PermissionCatalog.all.forEach { permission ->
                androidx.compose.foundation.layout.Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Checkbox(
                        checked = selectedPermissions.contains(permission),
                        onCheckedChange = { checked ->
                            selectedPermissions = if (checked) selectedPermissions + permission else selectedPermissions - permission
                        }
                    )
                    Text(permission, color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        OSINETButton(
            text = "GUARDAR USUARIO",
            enabled = fullName.isNotBlank() && username.isNotBlank() && password.isNotBlank() && (role != "ENCARGADO" || selectedBranchId != 0),
            onClick = {
                viewModel.saveUser(
                    com.example.controlhorario.database.AppUserEntity(
                        fullName = fullName.trim(),
                        username = username.trim(),
                        email = email.trim().lowercase(),
                        password = password,
                        role = role,
                        permissionsCsv = selectedPermissions.joinToString(","),
                        employeeId = selectedEmployeeId,
                        branchId = selectedBranchId,
                        createdAt = System.currentTimeMillis().toString(),
                        updatedAt = System.currentTimeMillis().toString()
                    )
                )
                message = "Usuario guardado correctamente."
                fullName = ""
                username = ""
                email = ""
                password = ""
                selectedEmployeeId = 0
                selectedBranchId = 0
                employeeSearch = ""
            }
        )
        if (message.isNotBlank()) {
            Spacer(Modifier.height(8.dp))
            Text(message, color = com.example.controlhorario.ui.components.OSINETColors.GreenSoft)
        }
        Spacer(Modifier.height(14.dp))
        Text("Usuarios activos", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
        users.forEach { user ->
            OSINETCard {
                Text("${user.fullName} · ${user.role}", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                Text("Usuario: ${user.username} · Correo: ${user.email.ifBlank { "Sin vincular" }} · Empleado ID: ${if (user.employeeId == 0) "No asignado" else user.employeeId}", color = com.example.controlhorario.ui.components.OSINETColors.TextSecondary)
            }
            Spacer(Modifier.height(6.dp))
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun EmployeePortalScreen(
    viewModel: EmployeePermissionRequestsViewModel,
    currentUser: AppUserEntity?,
    onBack: () -> Unit
) {
    var section by remember { mutableStateOf("MENU") }
    var lateHour by remember { mutableStateOf("") }
    var medicalMsg by remember { mutableStateOf("") }
    var medicalAttachment by remember { mutableStateOf("") }
    var licenseAttachment by remember { mutableStateOf("") }
    var personalMsg by remember { mutableStateOf("") }
    var loanAmount by remember { mutableStateOf("") }
    var loanDiscount by remember { mutableStateOf("") }
    var requestStatus by remember { mutableStateOf("Sin solicitudes enviadas") }
    fun submitPermission(type: String, message: String, attachment: String = "") {
        val now = portalNow()
        viewModel.saveRequest(
            EmployeePermissionRequestEntity(
                employeeId = currentUser?.employeeId ?: 0,
                employeeName = currentUser?.fullName ?: "Empleado",
                employeeCode = currentUser?.username ?: "",
                branchId = currentUser?.branchId ?: 0,
                departmentId = currentUser?.departmentId ?: 0,
                requestType = type,
                message = message.trim(),
                attachmentUri = attachment.substringAfter(": ", attachment),
                attachmentLabel = attachment,
                requestedDate = now,
                createdAt = now,
                updatedAt = now
            )
        )
    }
    val medicalFileLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) medicalAttachment = "Archivo cargado: $uri"
    }
    val medicalGalleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) medicalAttachment = "Foto de galería cargada: $uri"
    }
    val medicalCameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        if (bitmap != null) medicalAttachment = "Foto tomada con cámara"
    }
    val licenseFileLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) licenseAttachment = "Archivo cargado: $uri"
    }
    val licenseGalleryLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) licenseAttachment = "Foto de galería cargada: $uri"
    }
    val licenseCameraLauncher = rememberLauncherForActivityResult(ActivityResultContracts.TakePicturePreview()) { bitmap ->
        if (bitmap != null) licenseAttachment = "Foto tomada con cámara"
    }

    OSINETScreen {
        OSINETHeader(
            title = "Portal del Empleado",
            subtitle = "Información personal del empleado autenticado"
        )
        Spacer(Modifier.height(16.dp))
        if (section == "MENU") {
            OSINETActionCard("PAGOS", "Sueldo bruto, incentivos, horas extras, descuentos y total a cobrar", onClick = { section = "PAGOS" })
            Spacer(Modifier.height(10.dp))
            OSINETActionCard("PRÉSTAMOS", "Total, pendiente, solicitud y estado", onClick = { section = "PRESTAMOS" })
            Spacer(Modifier.height(10.dp))
            OSINETActionCard("HISTORIAL", "Descuentos de préstamos por nómina", onClick = { section = "HISTORIAL" })
            Spacer(Modifier.height(10.dp))
            OSINETActionCard("PERMISOS", "Llegaré tarde, médico, licencia médica y motivo personal", onClick = { section = "PERMISOS" })
            Spacer(Modifier.height(18.dp))
            OSINETSecondaryButton("Volver", onBack)
            return@OSINETScreen
        }

        when (section) {
            "PAGOS" -> {
                OSINETCard {
                    Text("Sueldo bruto: según última nómina generada", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Text("Incentivo: según perfil de nómina", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Text("Ganancia horas extras: calculada por ponches", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Text("Descuento crédito: según crédito activo", color = com.example.controlhorario.ui.components.OSINETColors.Danger)
                    Text("Descuento préstamo: según préstamo entregado", color = com.example.controlhorario.ui.components.OSINETColors.Danger)
                    Text("Otros descuentos: plantilla o perfil", color = com.example.controlhorario.ui.components.OSINETColors.Danger)
                    Text("Total a cobrar: resultado de nómina", color = com.example.controlhorario.ui.components.OSINETColors.GreenSoft)
                }
            }
            "PRESTAMOS" -> {
                OSINETCard {
                    Text("Total préstamo: se carga cuando el dinero está ENTREGADO", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Text("Pendiente a pagar: balance actual", color = com.example.controlhorario.ui.components.OSINETColors.Warning)
                    Text("Estado solicitud: $requestStatus", color = com.example.controlhorario.ui.components.OSINETColors.GreenSoft)
                }
                Spacer(Modifier.height(10.dp))
                OSINETCard {
                    Text("SOLICITAR PRÉSTAMO", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Spacer(Modifier.height(8.dp))
                    OSINETTextField(loanAmount, { loanAmount = it }, "Monto solicitado", Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    OSINETTextField(loanDiscount, { loanDiscount = it }, "Descuento quincenal", Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("ENVIAR SOLICITUD", enabled = loanAmount.isNotBlank() && loanDiscount.isNotBlank(), onClick = { requestStatus = "Pendiente de aprobación" })
                }
            }
            "HISTORIAL" -> {
                OSINETCard {
                    Text("Historial de descuentos de préstamos", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Text("Fecha · Monto descontado · Nómina · Balance pendiente", color = com.example.controlhorario.ui.components.OSINETColors.TextSecondary)
                    Text("Se alimentará automáticamente desde cada nómina generada.", color = com.example.controlhorario.ui.components.OSINETColors.GreenSoft)
                }
            }
            "PERMISOS" -> {
                OSINETCard {
                    Text("LLEGARÉ TARDE", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    OSINETTextField(lateHour, { lateHour = it }, "Hora estimada de llegada", Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("ENVIAR", enabled = lateHour.isNotBlank(), onClick = {
                        submitPermission(EmployeePermissionRequestEntity.TYPE_LATE, "Hora estimada de llegada: $lateHour")
                        lateHour = ""
                        requestStatus = "Permiso de llegada tarde enviado"
                    })
                }
                Spacer(Modifier.height(10.dp))
                OSINETCard {
                    Text("MÉDICO", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    OSINETTextField(medicalMsg, { medicalMsg = it }, "Mensaje", Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Adjunto: ${medicalAttachment.ifBlank { "Sin archivo o foto" }}",
                        color = com.example.controlhorario.ui.components.OSINETColors.TextSecondary
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OSINETButton("ARCHIVO", onClick = { medicalFileLauncher.launch(arrayOf("*/*")) }, modifier = Modifier.weight(1f))
                        OSINETButton("GALERÍA", onClick = { medicalGalleryLauncher.launch("image/*") }, modifier = Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("CÁMARA", onClick = { medicalCameraLauncher.launch(null) })
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("ENVIAR", enabled = medicalMsg.isNotBlank() || medicalAttachment.isNotBlank(), onClick = {
                        submitPermission(EmployeePermissionRequestEntity.TYPE_MEDICAL, medicalMsg, medicalAttachment)
                        medicalMsg = ""
                        medicalAttachment = ""
                        requestStatus = "Solicitud médica enviada"
                    })
                }
                Spacer(Modifier.height(10.dp))
                OSINETCard {
                    Text("LICENCIA MÉDICA", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    Text(
                        "Adjunto: ${licenseAttachment.ifBlank { "Sin archivo o foto" }}",
                        color = com.example.controlhorario.ui.components.OSINETColors.TextSecondary
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OSINETButton("ARCHIVO", onClick = { licenseFileLauncher.launch(arrayOf("*/*")) }, modifier = Modifier.weight(1f))
                        OSINETButton("GALERÍA", onClick = { licenseGalleryLauncher.launch("image/*") }, modifier = Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("CÁMARA", onClick = { licenseCameraLauncher.launch(null) })
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("ENVIAR", enabled = licenseAttachment.isNotBlank(), onClick = {
                        submitPermission(EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE, "Licencia médica enviada para revisión", licenseAttachment)
                        licenseAttachment = ""
                        requestStatus = "Licencia médica enviada a revisión"
                    })
                }
                Spacer(Modifier.height(10.dp))
                OSINETCard {
                    Text("MOTIVO PERSONAL", color = com.example.controlhorario.ui.components.OSINETColors.TextPrimary)
                    OSINETTextField(personalMsg, { personalMsg = it }, "Motivo", Modifier.fillMaxWidth())
                    Spacer(Modifier.height(8.dp))
                    OSINETButton("ENVIAR", enabled = personalMsg.isNotBlank(), onClick = {
                        submitPermission(EmployeePermissionRequestEntity.TYPE_PERSONAL, personalMsg)
                        personalMsg = ""
                        requestStatus = "Solicitud por motivo personal enviada"
                    })
                }
            }
        }
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Volver al Portal", onClick = { section = "MENU" })
    }
}

@Composable
private fun ModuleScreen(title: String, detail: String, onBack: () -> Unit) {
    OSINETScreen {
        OSINETHeader(title = title, subtitle = detail)
        Spacer(Modifier.height(24.dp))
        OSINETSecondaryButton("Volver", onBack)
    }
}

@Composable
private fun MenuButton(title: String, onClick: () -> Unit) {
    OSINETActionCard(title = title, onClick = onClick)
}

private fun portalNow(): String =
    SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.getDefault()).format(Date())

private object Route {
    const val DEVICE_ENROLLMENT = "device_enrollment"
    const val ROLE_SELECT = "role_select"
    const val ADMIN_LOGIN = "admin_login"
    const val KIOSK_MODE = "kiosk_mode"
    const val EMPLOYEE_PUNCH = "employee_punch"
    const val FACE_VERIFICATION = "face_verification"
    const val FACE_KIOSK_REGISTRATION = "face_kiosk_registration"
    const val KIOSK_EXIT_AUTH = "kiosk_exit_auth"
    const val EMPLOYEE_ASSISTANCE = "employee_assistance"
    const val EMPLOYEES_MENU = "employees_menu"
    const val EMPLOYEE_ADD = "employee_add"
    const val EMPLOYEE_EDIT = "employee_edit"
    const val EMPLOYEE_LIST = "employee_list"
    const val EMPLOYEE_SYNC_DASHBOARD = "employee_sync_dashboard"
    const val EMPLOYEE_PROFILE = "employee_profile"
    const val EMPLOYEE_FILE = "employee_file"
    const val EMPLOYEE_DOCUMENTS = "employee_documents"
    const val EMPLOYEE_DOCUMENT_UPLOAD = "employee_document_upload"
    const val EMPLOYEE_ATTENDANCE_HISTORY = "employee_attendance_history"
    const val EMPLOYEE_PAYROLL_SETTINGS = "employee_payroll_settings"
    const val EMPLOYEE_PAYROLL_PREVIEW = "employee_payroll_preview"
    const val EMPLOYEE_PAYROLL_HISTORY = "employee_payroll_history"
    const val ATTENDANCE = "attendance"
    const val PAYROLL_MENU = "payroll_menu"
    const val REPORTS_MENU = "reports_menu"
    const val SETTINGS_MENU = "settings_menu"
    const val ADMIN_EMPRESA = "admin_empresa"
    const val ADMIN_SUCURSALES = "admin_sucursales"
    const val ADMIN_DEPARTAMENTOS = "admin_departamentos"
    const val ADMIN_CARGOS = "admin_cargos"
    const val ADMIN_USUARIOS = "admin_usuarios"
    const val ADMIN_HORARIOS = "admin_horarios"
    const val ADMIN_JORNADAS = "admin_jornadas"
    const val ADMIN_DISPOSITIVOS = "admin_dispositivos"
    const val ADMIN_SEGURIDAD = "admin_seguridad"
    const val ADMIN_APARIENCIA = "admin_apariencia"
    const val VACATIONS_MENU = "vacations_menu"
    const val LOANS_MENU = "loans_menu"
    const val FINGERPRINTS = "fingerprints"
    const val PERMISSIONS = "permissions"
    const val EMPLOYEE_PERMISSION_REQUESTS = "employee_permission_requests"
    const val INCIDENTS_CENTER = "incidents_center"
    const val GENERAL_PAYROLL = "general_payroll"
    const val SUPERVISORS_ADMIN = "supervisors_admin"
    const val SUPERVISOR_LOGIN = "supervisor_login"
    const val SUPERVISOR_HOME = "supervisor_home"
    const val SUPERVISOR_JORNADAS = "supervisor_jornadas"
    const val SUPERVISOR_EVENTOS = "supervisor_eventos"
    const val SUPERVISOR_PERMISOS = "supervisor_permisos"
    const val SUPERVISOR_ADMIN_ON_OFF = "supervisor_admin_on_off"
    const val BRANCHES = "branches"
    const val DEPARTMENTS = "departments"
    const val COMPANY_SETTINGS = "company_settings"
    const val WORK_SCHEDULE = "work_schedule"
    const val PAYROLL_SETTINGS = "payroll_settings"
    const val LABOR_CALENDAR = "labor_calendar"
    const val USER_PERMISSIONS_ADMIN = "user_permissions_admin"
    const val EMPLOYEE_PORTAL = "employee_portal"
    const val BRANCH_MANAGER_PANEL = "branch_manager_panel"
    const val ADMIN_DASHBOARD = "admin_dashboard"
}
