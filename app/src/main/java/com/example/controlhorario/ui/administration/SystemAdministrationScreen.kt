package com.example.controlhorario.ui.administration

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
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
import com.example.controlhorario.auth.SupabaseRuntimeConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

enum class AdministrationSection(val wireName: String, val title: String, val description: String) {
    COMPANY("empresa", "Empresa", "RNC, dirección, contacto y zona horaria"),
    BRANCHES("sucursales", "Sucursales", "Ubicaciones, contacto y estado"),
    DEPARTMENTS("departamentos", "Departamentos", "Estructura por sucursal y supervisores"),
    POSITIONS("cargos", "Cargos", "Cargos laborales y departamentos"),
    USERS("usuarios", "Accesos", "Cuentas vinculadas a empleados, roles y estado"),
    SCHEDULES("horarios", "Horarios", "Turnos, días, tolerancia y almuerzo"),
    JOURNEYS("jornadas", "Jornadas", "Reglas, pendientes e incidencias"),
    DEVICES("dispositivos", "Dispositivos", "Android registrados y sincronización"),
    SECURITY("seguridad", "Seguridad", "Sesión, auditoría y accesos"),
}

data class AdministrationOverview(
    val companyName: String,
    val timezone: String,
    val taxId: String?,
    val logoUrl: String?,
    val role: String,
    val visibleSections: Set<String>,
    val counts: Map<String, Int>,
)

sealed interface AdministrationState {
    data object Loading : AdministrationState
    data class Ready(val overview: AdministrationOverview) : AdministrationState
    data class Error(val message: String) : AdministrationState
}

class SystemAdministrationGateway(
    baseUrl: String = BuildConfig.SUPABASE_URL,
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) {
    private val config = SupabaseRuntimeConfig.validate(baseUrl, publishableKey)

    suspend fun load(token: String): AdministrationOverview = withContext(Dispatchers.IO) {
        val connection = (URL("${config.baseUrl}/rest/v1/rpc/obtener_administracion_sistema").openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 20_000
            doOutput = true
            setRequestProperty("apikey", publishableKey)
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Content-Type", "application/json")
        }
        try {
            connection.outputStream.use { it.write("{}".toByteArray()) }
            val status = connection.responseCode
            val body = (if (status in 200..299) connection.inputStream else connection.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val error = runCatching { JSONObject(body) }.getOrNull()
                throw AuthFlowException(
                    stage = "system_administration",
                    code = error?.optString("code")?.takeIf(String::isNotBlank) ?: "HTTP_$status",
                    message = error?.optString("message")?.takeIf(String::isNotBlank) ?: "No fue posible cargar Administración del sistema.",
                    details = error?.optString("details")?.takeIf(String::isNotBlank),
                    hint = error?.optString("hint")?.takeIf(String::isNotBlank),
                )
            }
            parse(JSONObject(body))
        } finally {
            connection.disconnect()
        }
    }

    private fun parse(root: JSONObject): AdministrationOverview {
        val company = root.getJSONObject("company")
        val sections = root.getJSONObject("sections")
        val counts = root.getJSONObject("counts")
        val session = root.getJSONObject("session")
        return AdministrationOverview(
            companyName = company.getString("name"),
            timezone = company.getString("timezone"),
            taxId = company.optString("tax_id").takeIf { it.isNotBlank() && it != "null" },
            logoUrl = company.optString("logo_url").takeIf { it.isNotBlank() && it != "null" },
            role = session.optString("role"),
            visibleSections = AdministrationSection.entries.filter { sections.optBoolean(it.wireName) }.mapTo(mutableSetOf()) { it.wireName },
            counts = mapOf(
                "sucursales" to counts.optInt("branches"), "departamentos" to counts.optInt("departments"),
                "cargos" to counts.optInt("positions"), "usuarios" to counts.optInt("profiles"),
                "horarios" to counts.optInt("schedules"), "jornadas" to counts.optInt("pending_journeys"),
                "dispositivos" to counts.optInt("devices"), "seguridad" to counts.optInt("audit_events"),
            ),
        )
    }
}

class SystemAdministrationViewModel(
    principal: AuthenticatedPrincipal,
    gateway: SystemAdministrationGateway = SystemAdministrationGateway(),
) : ViewModel() {
    private val mutableState = MutableStateFlow<AdministrationState>(AdministrationState.Loading)
    val state: StateFlow<AdministrationState> = mutableState
    init {
        viewModelScope.launch {
            mutableState.value = try { AdministrationState.Ready(gateway.load(principal.accessToken)) }
            catch (error: AuthFlowException) { AdministrationState.Error(error.visibleMessage()) }
            catch (error: Exception) { AdministrationState.Error(error.message ?: "Error de red al cargar Administración del sistema.") }
        }
    }
}

class SystemAdministrationViewModelFactory(private val principal: AuthenticatedPrincipal) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T = SystemAdministrationViewModel(principal) as T
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SystemAdministrationDetailScreen(section: AdministrationSection, state: AdministrationState, onBack: () -> Unit) {
    AdministrationScaffold(section.title, onBack) { padding ->
        when (state) {
            AdministrationState.Loading -> CircularProgressIndicator(Modifier.padding(padding).padding(24.dp))
            is AdministrationState.Error -> Text(state.message, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(padding).padding(20.dp))
            is AdministrationState.Ready -> {
                if (section.wireName !in state.overview.visibleSections) Text("Permisos insuficientes para abrir esta sección.", color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(padding).padding(20.dp))
                else Column(Modifier.fillMaxSize().padding(padding).padding(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text(section.description, color = Color(0xFF91A5BF))
                    Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF101E33)), modifier = Modifier.fillMaxWidth()) { Column(Modifier.padding(18.dp)) {
                        Text(state.overview.companyName, fontWeight = FontWeight.Bold)
                        SectionDetail(section, state.overview)
                    } }
                    Text("Los cambios administrativos completos se realizan en Web. Android muestra el contexto real sin duplicar la lógica de mantenimiento.", style = MaterialTheme.typography.bodySmall, color = Color(0xFF91A5BF))
                }
            }
        }
    }
}

@Composable private fun SectionDetail(section: AdministrationSection, overview: AdministrationOverview) {
    val detail = when (section) {
        AdministrationSection.COMPANY -> "RNC: ${overview.taxId ?: "No configurado"}\nZona horaria: ${overview.timezone}"
        AdministrationSection.SECURITY -> "Rol efectivo: ${overview.role}\nEventos auditados: ${overview.counts[section.wireName] ?: 0}"
        else -> "Registros visibles: ${overview.counts[section.wireName] ?: 0}"
    }
    Text(detail, modifier = Modifier.padding(top = 8.dp))
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable private fun AdministrationScaffold(title: String, onBack: () -> Unit, content: @Composable (androidx.compose.foundation.layout.PaddingValues) -> Unit) {
    Scaffold(containerColor = Color(0xFF07101F), topBar = { TopAppBar(title = { Text(title) }, navigationIcon = { IconButton(onClick = onBack) { Text("←", style = MaterialTheme.typography.titleLarge) } }) }, content = content)
}
