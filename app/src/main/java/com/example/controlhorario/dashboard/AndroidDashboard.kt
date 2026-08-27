package com.example.controlhorario.dashboard

import android.util.Log
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.SafeHttpDiagnostics
import com.example.controlhorario.auth.SupabaseRuntimeConfig
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class DashboardMetrics(
    val workDate: String,
    val totalEmployees: Int? = null,
    val activeEmployees: Int? = null,
    val notStarted: Int,
    val inProgress: Int,
    val paused: Int,
    val finished: Int,
    val pending: Int,
    val incidents: Int? = null,
)

data class DashboardEmployeeRow(
    val id: String,
    val active: Boolean,
    val journeyEnabled: Boolean,
)

data class DashboardJourneyRow(
    val employeeId: String,
    val status: String,
    val pendingReview: Boolean,
)

object DashboardMetricsCalculator {
    fun calculate(
        workDate: String,
        employees: List<DashboardEmployeeRow>,
        journeys: List<DashboardJourneyRow>,
        unreadOpenIncidents: Int,
    ): DashboardMetrics {
        val eligibleEmployeeIds = employees.asSequence()
            .filter { it.active && it.journeyEnabled }
            .map { it.id }
            .toSet()
        val employeesWithJourney = journeys.mapTo(mutableSetOf()) { it.employeeId }
        return DashboardMetrics(
            workDate = workDate,
            totalEmployees = employees.size,
            activeEmployees = employees.count { it.active },
            notStarted = eligibleEmployeeIds.count { it !in employeesWithJourney },
            inProgress = journeys.count { it.status == "EN_CURSO" },
            paused = journeys.count { it.status == "EN_PAUSA" },
            finished = journeys.count { it.status == "FINALIZADA" },
            pending = journeys.count { it.pendingReview },
            incidents = unreadOpenIncidents,
        )
    }
}

object CompanyWorkDate {
    fun resolve(timezone: String, clock: Clock): String =
        LocalDate.now(clock.withZone(ZoneId.of(timezone))).toString()
}

sealed interface DashboardState {
    data object Loading : DashboardState
    data class Ready(val metrics: DashboardMetrics, val source: String) : DashboardState
    data class Error(val message: String) : DashboardState
}

enum class DashboardDestination {
    ADMIN,
    SUPERVISOR,
    EMPLOYEE,
    RRHH,
    NOMINA,
    AUDITOR,
    UNKNOWN,
}

object DashboardResolver {
    fun resolve(canonicalRoleCode: String?): DashboardDestination =
        when (canonicalRoleCode?.trim()?.uppercase()) {
            "ADMIN" -> DashboardDestination.ADMIN
            "SUPERVISOR" -> DashboardDestination.SUPERVISOR
            "EMPLEADO", "EMPLEADOS", "EMPLOYEE", "EMPLOYEES" ->
                DashboardDestination.EMPLOYEE
            "RRHH" -> DashboardDestination.RRHH
            "NOMINA" -> DashboardDestination.NOMINA
            "AUDITOR" -> DashboardDestination.AUDITOR
            else -> DashboardDestination.UNKNOWN
        }

    fun dashboardLabel(destination: DashboardDestination): String = when (destination) {
        DashboardDestination.ADMIN -> "DashboardAdministrador"
        DashboardDestination.SUPERVISOR -> "DashboardSupervisor"
        DashboardDestination.EMPLOYEE -> "DashboardEmpleado"
        DashboardDestination.RRHH -> "DashboardRRHH"
        DashboardDestination.NOMINA -> "DashboardNomina"
        DashboardDestination.AUDITOR -> "DashboardAuditor"
        DashboardDestination.UNKNOWN -> "UnknownRole"
    }

    fun isAdministrativeDestination(destination: DashboardDestination): Boolean =
        destination in setOf(
            DashboardDestination.ADMIN,
            DashboardDestination.RRHH,
            DashboardDestination.NOMINA,
            DashboardDestination.AUDITOR,
        )
}

interface DashboardGateway {
    suspend fun supervisorDashboard(token: String): DashboardMetrics
    suspend fun scopedDashboard(token: String, companyId: String): DashboardMetrics
}

class SupabaseDashboardGateway(
    private val baseUrl: String = BuildConfig.SUPABASE_URL,
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
    private val clock: Clock = Clock.systemUTC(),
) : DashboardGateway {
    private val config = SupabaseRuntimeConfig.validate(baseUrl, publishableKey)

    override suspend fun supervisorDashboard(token: String): DashboardMetrics =
        withContext(Dispatchers.IO) {
            val json = JSONObject(
                request(
                    "POST",
                    "/rest/v1/rpc/dashboard_supervisor",
                    token,
                    "{}",
                    "rpc dashboard_supervisor",
                ),
            )
            DashboardMetrics(
                workDate = json.optString("fecha_laboral"),
                totalEmployees = json.optInt("total_empleados"),
                activeEmployees = json.optInt("activos"),
                notStarted = json.optInt("sin_iniciar"),
                inProgress = json.optInt("en_curso"),
                paused = json.optInt("en_pausa"),
                finished = json.optInt("finalizadas"),
                pending = json.optInt("pendientes"),
                incidents = json.optInt("incidencias_nuevas"),
            )
        }

    override suspend fun scopedDashboard(
        token: String,
        companyId: String,
    ): DashboardMetrics = withContext(Dispatchers.IO) {
        val encodedCompany = encode("eq.$companyId")
        val companyRows = JSONArray(
            request(
                "GET",
                "/rest/v1/companies?select=timezone&id=$encodedCompany&limit=1",
                token,
                stage = "company timezone",
            ),
        )
        val timezone = companyRows.optJSONObject(0)
            ?.optString("timezone")
            ?.takeIf(String::isNotBlank)
            ?: throw AuthFlowException(
                "company timezone",
                "COMPANY_TIMEZONE_NOT_FOUND",
                "No fue posible obtener la zona horaria de la empresa.",
            )
        val workDate = try {
            CompanyWorkDate.resolve(timezone, clock)
        } catch (error: Exception) {
            throw AuthFlowException(
                "company timezone",
                "INVALID_COMPANY_TIMEZONE",
                "La empresa tiene una zona horaria invalida.",
                details = timezone,
                cause = error,
            )
        }
        val employeeRows = JSONArray(
            request(
                "GET",
                "/rest/v1/empleados?select=id,activo,jornada_habilitada&empresa_id=$encodedCompany",
                token,
                stage = "empleados visibles",
            ),
        )
        val select = encode("empleado_id,estado,revision_pendiente")
        val date = encode("eq.$workDate")
        val journeyRows = JSONArray(
            request(
                "GET",
                "/rest/v1/jornadas?select=$select&empresa_id=$encodedCompany&fecha_laboral=$date",
                token,
                stage = "jornadas dashboard",
            ),
        )
        val incidentRows = JSONArray(
            request(
                "GET",
                "/rest/v1/jornada_incidencias?select=id&empresa_id=$encodedCompany&resuelta=eq.false&leida=eq.false",
                token,
                stage = "incidencias dashboard",
            ),
        )
        DashboardMetricsCalculator.calculate(
            workDate = workDate,
            employees = buildList {
                repeat(employeeRows.length()) {
                    val row = employeeRows.getJSONObject(it)
                    add(
                        DashboardEmployeeRow(
                            row.getString("id"),
                            row.optBoolean("activo"),
                            row.optBoolean("jornada_habilitada", true),
                        ),
                    )
                }
            },
            journeys = buildList {
                repeat(journeyRows.length()) {
                    val row = journeyRows.getJSONObject(it)
                    add(
                        DashboardJourneyRow(
                            row.getString("empleado_id"),
                            row.optString("estado"),
                            row.optBoolean("revision_pendiente"),
                        ),
                    )
                }
            },
            unreadOpenIncidents = incidentRows.length(),
        )
    }

    private fun encode(value: String): String =
        URLEncoder.encode(value, Charsets.UTF_8.name())

    private fun request(
        method: String,
        path: String,
        token: String,
        body: String? = null,
        stage: String,
    ): String {
        var connection: HttpURLConnection? = null
        try {
            val fullUrl = "${config.baseUrl}$path"
            SafeHttpDiagnostics.request("AndroidDashboard", method, fullUrl, config)
            connection = (URL(fullUrl).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15_000
                readTimeout = 25_000
                setRequestProperty("apikey", config.publishableKey)
                setRequestProperty("Authorization", "Bearer $token")
                setRequestProperty("Accept", "application/json")
                if (body != null) {
                    doOutput = true
                    setRequestProperty("Content-Type", "application/json")
                    outputStream.use { it.write(body.toByteArray()) }
                }
            }
            val status = connection.responseCode
            val response = (
                if (status in 200..299) connection.inputStream else connection.errorStream
            )?.bufferedReader()?.use { it.readText() }.orEmpty()
            SafeHttpDiagnostics.response("AndroidDashboard", status, response)
            if (status !in 200..299) {
                val json = runCatching { JSONObject(response) }.getOrNull()
                throw AuthFlowException(
                    stage,
                    json?.optString("code")?.takeIf(String::isNotBlank) ?: "HTTP_$status",
                    json?.optString("message")?.takeIf(String::isNotBlank)
                        ?: "Dashboard devolvio HTTP $status.",
                    json?.optString("details")?.takeIf(String::isNotBlank),
                    json?.optString("hint")?.takeIf(String::isNotBlank),
                )
            }
            return response
        } catch (error: AuthFlowException) {
            throw error
        } catch (error: Exception) {
            val classified = SafeHttpDiagnostics.exception("AndroidDashboard", stage, error)
            throw AuthFlowException(stage, classified.code, classified.message, cause = error)
        } finally {
            connection?.disconnect()
        }
    }
}

class AndroidDashboardViewModel(
    private val principal: AuthenticatedPrincipal,
    private val destination: DashboardDestination,
    private val gateway: DashboardGateway,
) : ViewModel() {
    private val _state = MutableStateFlow<DashboardState>(DashboardState.Loading)
    val state: StateFlow<DashboardState> = _state

    init {
        load()
    }

    fun load() {
        _state.value = DashboardState.Loading
        viewModelScope.launch {
            Log.i(
                TAG,
                "rol_recibido=${principal.roleCodeOriginal}; " +
                    "rol_canonico=${principal.roleCode}; " +
                    "dashboard_seleccionado=${DashboardResolver.dashboardLabel(destination)}; " +
                    "role_id=${principal.roleId}; company_id=${principal.companyId}",
            )
            try {
                _state.value = when (destination) {
                    DashboardDestination.SUPERVISOR ->
                        DashboardState.Ready(
                            gateway.supervisorDashboard(principal.accessToken),
                            "RC3",
                        )
                    DashboardDestination.ADMIN,
                    DashboardDestination.RRHH,
                    DashboardDestination.NOMINA,
                    DashboardDestination.AUDITOR,
                    DashboardDestination.EMPLOYEE ->
                        DashboardState.Ready(
                            gateway.scopedDashboard(principal.accessToken, principal.companyId),
                            DashboardResolver.dashboardLabel(destination),
                        )
                    DashboardDestination.UNKNOWN ->
                        DashboardState.Error("Rol no reconocido.")
                }
            } catch (error: AuthFlowException) {
                if (destination == DashboardDestination.SUPERVISOR) {
                    logSupervisorDashboardError(error)
                    _state.value = DashboardState.Error(friendlySupervisorMessage(error))
                } else {
                    Log.e(
                        TAG,
                        "consulta=${error.stage}; code=${error.code}; error=${error.message}; " +
                            "details=${error.details}; hint=${error.hint}",
                    )
                    _state.value = DashboardState.Error(error.visibleMessage())
                }
            } catch (error: Exception) {
                Log.e(TAG, "dashboard=exception; error=${error.message}", error)
                _state.value = DashboardState.Error(
                    error.message ?: "Error de Dashboard no identificado.",
                )
            }
        }
    }

    private fun logSupervisorDashboardError(error: AuthFlowException) {
        val detail = runCatching { JSONObject(error.details ?: "") }.getOrNull()
        Log.e(
            TAG,
            "rpc_dashboard=dashboard_supervisor; " +
                "user_id_presente=${detail?.optBoolean("user_id_presente", false)}; " +
                "empresa_id_presente=${detail?.optBoolean("empresa_id_presente", false)}; " +
                "role_code=${detail?.optString("role_code", principal.roleCode)}; " +
                "permiso_solicitado=${detail?.optString("permiso_solicitado", "supervisor.dashboard")}; " +
                "departamentos_asignados_count=${detail?.optInt("departamentos_asignados_count", -1)}; " +
                "resultado_scope=${detail?.optString("resultado_scope", "desconocido")}; " +
                "postgres_code=${error.code ?: "unknown"}",
        )
    }

    private fun friendlySupervisorMessage(error: AuthFlowException): String {
        val resultScope = runCatching {
            JSONObject(error.details ?: "").optString("resultado_scope")
        }.getOrNull()
        return when (resultScope) {
            "SIN_DEPARTAMENTOS" ->
                "No tienes departamentos asignados. Contacta al administrador."
            "SIN_PERMISO" ->
                "Tu usuario no tiene permiso para consultar este dashboard."
            "ROL_NO_SUPERVISOR",
            "PERFIL_INCONSISTENTE",
            "SCOPE_NO_AUTORIZADO" ->
                "No fue posible validar tu acceso. Cierra sesion e intentalo nuevamente."
            else -> if (error.code == "P0001") {
                "No fue posible validar tu acceso. Cierra sesion e intentalo nuevamente."
            } else {
                error.visibleMessage()
            }
        }
    }

    companion object {
        private const val TAG = "AndroidDashboard"
    }
}

class AndroidDashboardViewModelFactory(
    private val principal: AuthenticatedPrincipal,
    private val destination: DashboardDestination,
    private val gateway: DashboardGateway = SupabaseDashboardGateway(),
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        AndroidDashboardViewModel(principal, destination, gateway) as T
}

@Composable
fun AndroidDashboardPanel(state: DashboardState) {
    when (state) {
        DashboardState.Loading -> Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
        ) {
            CircularProgressIndicator(color = OSINETColors.GreenSoft)
        }
        is DashboardState.Error ->
            OSINETCard { Text(state.message, color = OSINETColors.Danger) }
        is DashboardState.Ready -> {
            OSINETCard {
                Text(
                    "Dashboard ${state.source}",
                    color = OSINETColors.GreenSoft,
                    fontWeight = FontWeight.SemiBold,
                )
                Text(
                    "Fecha laboral de la empresa - ${state.metrics.workDate}",
                    color = OSINETColors.TextSecondary,
                )
                state.metrics.totalEmployees?.let {
                    Text(
                        "$it empleados visibles - ${state.metrics.activeEmployees ?: 0} activos",
                        color = OSINETColors.TextPrimary,
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            DashboardMetricRow("Sin iniciar", state.metrics.notStarted, "En curso", state.metrics.inProgress)
            Spacer(Modifier.height(10.dp))
            DashboardMetricRow("En pausa", state.metrics.paused, "Finalizadas", state.metrics.finished)
            Spacer(Modifier.height(10.dp))
            DashboardMetricRow(
                "Pendientes",
                state.metrics.pending,
                "Incidencias",
                state.metrics.incidents ?: 0,
                dangerSecond = (state.metrics.incidents ?: 0) > 0,
            )
        }
    }
}

@Composable
private fun DashboardMetricRow(
    firstLabel: String,
    firstValue: Int,
    secondLabel: String,
    secondValue: Int,
    dangerSecond: Boolean = false,
) {
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        DashboardMetricCard(
            firstLabel,
            firstValue,
            OSINETColors.GreenSoft,
            Modifier.weight(1f),
        )
        DashboardMetricCard(
            secondLabel,
            secondValue,
            if (dangerSecond) OSINETColors.Danger else OSINETColors.Info,
            Modifier.weight(1f),
        )
    }
}

@Composable
private fun DashboardMetricCard(
    label: String,
    value: Int,
    accent: Color,
    modifier: Modifier,
) {
    OSINETCard(modifier) {
        Text(value.toString(), color = accent, fontWeight = FontWeight.Bold)
        Text(label, color = OSINETColors.TextSecondary)
    }
}

@Composable
fun AuthenticatedSupervisorDashboard(
    principal: AuthenticatedPrincipal,
    state: DashboardState,
    onLogout: () -> Unit,
) {
    OSINETScreen {
        OSINETHeader("Dashboard Supervisor", principal.fullName)
        Spacer(Modifier.height(16.dp))
        AndroidDashboardPanel(state)
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Cerrar sesion", onLogout)
    }
}
