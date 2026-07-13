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
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.auth.AuthFlowException
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.ui.components.OSINETCard
import com.example.controlhorario.ui.components.OSINETColors
import com.example.controlhorario.ui.components.OSINETHeader
import com.example.controlhorario.ui.components.OSINETScreen
import com.example.controlhorario.ui.components.OSINETSecondaryButton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.time.LocalDate

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

sealed interface DashboardState {
    data object Loading : DashboardState
    data class Ready(val metrics: DashboardMetrics, val source: String) : DashboardState
    data class Error(val message: String) : DashboardState
}

enum class DashboardDestination { LOADING, ADMIN, SUPERVISOR_RC3, SUPERVISOR_FALLBACK, ERROR }

object DashboardRoutePolicy {
    fun destination(roleCode: String?, permissionCodes: Set<String>, loading: Boolean): DashboardDestination {
        if (loading) return DashboardDestination.LOADING
        return when (roleCode) {
            "admin" -> DashboardDestination.ADMIN
            "supervisor" -> if ("supervisor.dashboard" in permissionCodes) DashboardDestination.SUPERVISOR_RC3 else DashboardDestination.SUPERVISOR_FALLBACK
            else -> DashboardDestination.ERROR
        }
    }

    fun shouldFallbackFromRc3(code: String?): Boolean = code in setOf("PGRST202", "42883", "HTTP_404")
}

interface DashboardGateway {
    suspend fun supervisorDashboard(token: String): DashboardMetrics
    suspend fun legacyDashboard(token: String, workDate: String): DashboardMetrics
}

class SupabaseDashboardGateway(
    private val baseUrl: String = BuildConfig.SUPABASE_URL,
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) : DashboardGateway {
    override suspend fun supervisorDashboard(token: String): DashboardMetrics {
        val json = JSONObject(request("POST", "/rest/v1/rpc/dashboard_supervisor", token, "{}", "rpc dashboard_supervisor"))
        return DashboardMetrics(
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

    override suspend fun legacyDashboard(token: String, workDate: String): DashboardMetrics {
        val select = URLEncoder.encode("id,estado,revision_pendiente,severidad,actualizada_en,fecha_laboral", Charsets.UTF_8.name())
        val date = URLEncoder.encode("eq.$workDate", Charsets.UTF_8.name())
        val rows = JSONArray(request("GET", "/rest/v1/jornadas?select=$select&fecha_laboral=$date", token, stage = "jornadas RC2"))
        val states = buildList { repeat(rows.length()) { add(rows.getJSONObject(it)) } }
        return DashboardMetrics(
            workDate = workDate,
            notStarted = states.count { it.optString("estado") == "SIN_INICIAR" },
            inProgress = states.count { it.optString("estado") == "EN_CURSO" },
            paused = states.count { it.optString("estado") == "EN_PAUSA" },
            finished = states.count { it.optString("estado") == "FINALIZADA" },
            pending = states.count { it.optBoolean("revision_pendiente") },
        )
    }

    private fun request(method: String, path: String, token: String, body: String? = null, stage: String): String {
        var connection: HttpURLConnection? = null
        try {
            connection = (URL("$baseUrl$path").openConnection() as HttpURLConnection).apply {
                requestMethod = method; connectTimeout = 15_000; readTimeout = 25_000
                setRequestProperty("apikey", publishableKey); setRequestProperty("Authorization", "Bearer $token"); setRequestProperty("Accept", "application/json")
                if (body != null) { doOutput = true; setRequestProperty("Content-Type", "application/json"); outputStream.use { it.write(body.toByteArray()) } }
            }
            val status = connection.responseCode
            val response = (if (status in 200..299) connection.inputStream else connection.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val json = runCatching { JSONObject(response) }.getOrNull()
                throw AuthFlowException(stage, json?.optString("code")?.takeIf(String::isNotBlank) ?: "HTTP_$status", json?.optString("message")?.takeIf(String::isNotBlank) ?: "Dashboard devolvió HTTP $status.", json?.optString("details")?.takeIf(String::isNotBlank), json?.optString("hint")?.takeIf(String::isNotBlank))
            }
            return response
        } catch (error: AuthFlowException) { throw error }
        catch (error: Exception) { throw AuthFlowException(stage, "NETWORK_ERROR", error.message ?: "Error de red.", cause = error) }
        finally { connection?.disconnect() }
    }
}

class AndroidDashboardViewModel(
    private val principal: AuthenticatedPrincipal,
    private val gateway: DashboardGateway,
) : ViewModel() {
    private val _state = MutableStateFlow<DashboardState>(DashboardState.Loading)
    val state: StateFlow<DashboardState> = _state

    init { load() }

    fun load() {
        _state.value = DashboardState.Loading
        viewModelScope.launch {
            val destination = DashboardRoutePolicy.destination(principal.roleCode, principal.permissionCodes, loading = false)
            Log.i(TAG, "role_id=${principal.roleId}; company_id=${principal.companyId}; permisos=${principal.permissionCodes.sorted().joinToString(",")}; destino=$destination")
            try {
                val result = when (destination) {
                    DashboardDestination.SUPERVISOR_RC3 -> try {
                        DashboardState.Ready(gateway.supervisorDashboard(principal.accessToken), "RC3")
                    } catch (error: AuthFlowException) {
                        if (DashboardRoutePolicy.shouldFallbackFromRc3(error.code)) {
                            Log.w(TAG, "rpc_rc3_no_disponible=true; fallback=RC2; codigo=${error.code}; error=${error.message}")
                            if (principal.permissionCodes.none { it == "jornadas.ver_todas" || it == "jornadas.ver_asignadas" }) throw AuthFlowException("dashboard_permissions", "JOURNEYS_PERMISSION_MISSING", "La sesión no tiene permiso para consultar jornadas; no se mostrarán métricas en cero.")
                            DashboardState.Ready(gateway.legacyDashboard(principal.accessToken, LocalDate.now().toString()), "RC2 fallback")
                        } else throw error
                    }
                    DashboardDestination.SUPERVISOR_FALLBACK, DashboardDestination.ADMIN -> {
                        if (principal.permissionCodes.none { it == "jornadas.ver_todas" || it == "jornadas.ver_asignadas" }) throw AuthFlowException("dashboard_permissions", "JOURNEYS_PERMISSION_MISSING", "La sesión no tiene permiso para consultar jornadas; no se mostrarán métricas en cero.")
                        DashboardState.Ready(gateway.legacyDashboard(principal.accessToken, LocalDate.now().toString()), if (destination == DashboardDestination.ADMIN) "RC2 admin" else "RC2 fallback")
                    }
                    DashboardDestination.ERROR -> throw AuthFlowException("dashboard_route", "INVALID_ROLE", "El rol no tiene un Dashboard Android válido.")
                    DashboardDestination.LOADING -> return@launch
                }
                _state.value = result
            } catch (error: AuthFlowException) {
                Log.e(TAG, "consulta=${error.stage}; code=${error.code}; error=${error.message}; details=${error.details}; hint=${error.hint}; role_id=${principal.roleId}; company_id=${principal.companyId}")
                _state.value = DashboardState.Error(error.visibleMessage())
            } catch (error: Exception) {
                Log.e(TAG, "dashboard=excepcion; error=${error.message}", error)
                _state.value = DashboardState.Error(error.message ?: "Error de Dashboard no identificado.")
            }
        }
    }

    companion object { private const val TAG = "AndroidDashboard" }
}

class AndroidDashboardViewModelFactory(private val principal: AuthenticatedPrincipal, private val gateway: DashboardGateway = SupabaseDashboardGateway()) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST") override fun <T : ViewModel> create(modelClass: Class<T>): T = AndroidDashboardViewModel(principal, gateway) as T
}

@Composable
fun AndroidDashboardPanel(state: DashboardState) {
    when (state) {
        DashboardState.Loading -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.Center) { CircularProgressIndicator(color = OSINETColors.GreenSoft) }
        is DashboardState.Error -> OSINETCard { Text(state.message, color = OSINETColors.Danger) }
        is DashboardState.Ready -> {
            OSINETCard {
                Text("Dashboard ${state.source}", color = OSINETColors.GreenSoft)
                Text("Fecha laboral: ${state.metrics.workDate}", color = OSINETColors.TextSecondary)
                state.metrics.totalEmployees?.let { Text("Empleados visibles: $it", color = OSINETColors.TextPrimary) }
                state.metrics.activeEmployees?.let { Text("Activos: $it", color = OSINETColors.TextPrimary) }
                Text("Sin iniciar: ${state.metrics.notStarted}", color = OSINETColors.TextPrimary)
                Text("En curso: ${state.metrics.inProgress}", color = OSINETColors.TextPrimary)
                Text("En pausa: ${state.metrics.paused}", color = OSINETColors.TextPrimary)
                Text("Finalizadas: ${state.metrics.finished}", color = OSINETColors.TextPrimary)
                Text("Pendientes: ${state.metrics.pending}", color = OSINETColors.TextPrimary)
                state.metrics.incidents?.let { Text("Incidencias: $it", color = OSINETColors.TextPrimary) }
            }
        }
    }
}

@Composable
fun AuthenticatedSupervisorDashboard(principal: AuthenticatedPrincipal, state: DashboardState, onLogout: () -> Unit) {
    OSINETScreen {
        OSINETHeader("Dashboard Supervisor", principal.fullName)
        Spacer(Modifier.height(16.dp))
        AndroidDashboardPanel(state)
        Spacer(Modifier.height(18.dp))
        OSINETSecondaryButton("Cerrar sesión", onLogout)
    }
}
