package com.example.controlhorario.ui.administration

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.auth.AuthenticatedPrincipal
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

data class ManagedAndroidDevice(
    val id: String,
    val name: String,
    val model: String,
    val androidVersion: String,
    val appVersion: String,
    val state: String,
    val branchId: String?,
    val branchName: String,
    val lastConnectionAt: String?,
    val registeredAt: String?,
    val usageType: String,
    val voiceEnabled: Boolean,
    val configurationRevision: Long,
    val departmentIds: Set<String>,
) {
    val retired: Boolean get() = state.equals("revocado", ignoreCase = true)
}

data class DeviceAdminBranch(val id: String, val name: String, val active: Boolean)
data class DeviceAdminDepartment(val id: String, val branchId: String, val name: String, val active: Boolean)

data class DeviceAdministrationCatalog(
    val devices: List<ManagedAndroidDevice>,
    val branches: List<DeviceAdminBranch>,
    val departments: List<DeviceAdminDepartment>,
)

data class DeviceEditorDraft(
    val deviceId: String,
    val name: String,
    val state: String,
    val voiceEnabled: Boolean,
    val branchId: String,
    val usageType: String,
    val departmentIds: Set<String>,
    val reason: String = "",
)

object DeviceAdministrationPolicy {
    private val viewPermissions = setOf(
        "dispositivos.ver",
        "dispositivos.registrar",
        "dispositivos.revocar",
        "kiosk.face_mode_manage",
    )
    private val managePermissions = setOf("dispositivos.registrar", "kiosk.face_mode_manage")

    fun canView(permissions: Set<String>): Boolean = permissions.any(viewPermissions::contains)
    fun canManage(permissions: Set<String>): Boolean = permissions.any(managePermissions::contains)

    fun departmentsFor(usageType: String, selected: Set<String>): Set<String> =
        if (usageType == "DEPARTMENTS") selected else emptySet()

    fun validationMessage(
        draft: DeviceEditorDraft,
        catalog: DeviceAdministrationCatalog,
    ): String? {
        if (draft.name.trim().length !in 2..80) return "Ingrese un nombre de 2 a 80 caracteres."
        val branch = catalog.branches.firstOrNull { it.id == draft.branchId && it.active }
            ?: return "Seleccione una sucursal activa."
        if (draft.usageType !in setOf("GENERAL", "DEPARTMENTS")) return "Seleccione un tipo de terminal válido."
        if (draft.usageType == "DEPARTMENTS") {
            if (draft.departmentIds.isEmpty()) return "SELECCIONE AL MENOS UN DEPARTAMENTO"
            val available = catalog.departments
                .filter { it.branchId == branch.id && it.active }
                .mapTo(mutableSetOf()) { it.id }
            if (!available.containsAll(draft.departmentIds)) {
                return "La selección contiene departamentos fuera de la sucursal o del alcance autorizado."
            }
        }
        if (draft.reason.trim().length !in 5..500) return "Ingrese un motivo de al menos 5 caracteres."
        return null
    }
}

sealed interface DeviceAdministrationState {
    data object Loading : DeviceAdministrationState
    data class Ready(
        val catalog: DeviceAdministrationCatalog,
        val canManage: Boolean,
        val draft: DeviceEditorDraft? = null,
        val saving: Boolean = false,
        val message: String = "",
    ) : DeviceAdministrationState
    data class AccessDenied(val message: String) : DeviceAdministrationState
    data class Error(val message: String) : DeviceAdministrationState
}

class DeviceAdministrationGateway(
    private val baseUrl: String = BuildConfig.SUPABASE_URL.trimEnd('/'),
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) {
    suspend fun load(principal: AuthenticatedPrincipal): DeviceAdministrationCatalog = withContext(Dispatchers.IO) {
        val body = request(
            url = "$baseUrl/rest/v1/rpc/listar_dispositivos_android_administracion",
            token = principal.accessToken,
            payload = "{}",
        )
        JSONObject(body).toCatalog()
    }

    suspend fun update(principal: AuthenticatedPrincipal, draft: DeviceEditorDraft) = withContext(Dispatchers.IO) {
        val departments = DeviceAdministrationPolicy.departmentsFor(draft.usageType, draft.departmentIds)
        request(
            url = "$baseUrl/rest/v1/rpc/actualizar_dispositivo_android_administracion",
            token = principal.accessToken,
            payload = JSONObject()
                .put("p_dispositivo", draft.deviceId)
                .put("p_nombre", draft.name.trim())
                .put("p_estado", draft.state)
                .put("p_voz_habilitada", draft.voiceEnabled)
                .put("p_sucursal", draft.branchId)
                .put("p_tipo", draft.usageType)
                .put("p_departamentos", JSONArray(departments.toList()))
                .put("p_motivo", draft.reason.trim())
                .toString(),
        )
    }

    private fun request(url: String, token: String, payload: String): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 25_000
            doOutput = true
            setRequestProperty("apikey", publishableKey)
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Content-Type", "application/json")
        }
        return try {
            connection.outputStream.use { it.write(payload.toByteArray()) }
            val status = connection.responseCode
            val body = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val serverMessage = runCatching { JSONObject(body).optString("message") }.getOrNull().orEmpty()
                throw IllegalStateException(visibleServerError(serverMessage, status))
            }
            body
        } finally {
            connection.disconnect()
        }
    }

    private fun visibleServerError(message: String, status: Int): String = when (message) {
        "DEVICE_ADMIN_PERMISSION_DENIED" -> "No tiene permiso para administrar dispositivos."
        "DEVICE_ADMIN_SCOPE_DENIED" -> "El terminal o la sucursal están fuera de su alcance autorizado."
        "DEVICE_NAME_INVALID" -> "El nombre del terminal no es válido."
        "DEVICE_STATE_INVALID" -> "El estado solicitado no es válido."
        "DEVICE_REASON_REQUIRED" -> "Debe registrar un motivo para guardar los cambios."
        "DEVICE_REVOKED" -> "Un dispositivo revocado no se puede reactivar."
        "TERMINAL_DEPARTMENT_REQUIRED" -> "SELECCIONE AL MENOS UN DEPARTAMENTO"
        "TERMINAL_DEPARTMENT_INVALID" -> "Hay departamentos fuera de la sucursal seleccionada."
        else -> message.takeIf(String::isNotBlank) ?: "Supabase devolvió HTTP $status"
    }

    private fun JSONObject.toCatalog(): DeviceAdministrationCatalog = DeviceAdministrationCatalog(
        devices = optJSONArray("devices").objects().map { row ->
            ManagedAndroidDevice(
                id = row.optString("id"),
                name = row.optString("name", "Terminal Android"),
                model = row.optString("model"),
                androidVersion = row.optString("android_version"),
                appVersion = row.optString("app_version"),
                state = row.optString("state", "inactivo"),
                branchId = row.optionalString("branch_id"),
                branchName = row.optString("branch_name"),
                lastConnectionAt = row.optionalString("last_connection_at"),
                registeredAt = row.optionalString("registered_at"),
                usageType = row.optString("usage_type", "GENERAL").uppercase()
                    .takeIf { it in setOf("GENERAL", "DEPARTMENTS") } ?: "GENERAL",
                voiceEnabled = row.optBoolean("voice_enabled", true),
                configurationRevision = row.optLong("configuration_revision", 0L),
                departmentIds = row.optJSONArray("department_ids").strings(),
            )
        },
        branches = optJSONArray("branches").objects().map { row ->
            DeviceAdminBranch(row.optString("id"), row.optString("name"), row.optBoolean("active", true))
        },
        departments = optJSONArray("departments").objects().map { row ->
            DeviceAdminDepartment(
                row.optString("id"),
                row.optString("branch_id"),
                row.optString("name"),
                row.optBoolean("active", true),
            )
        },
    )

    private fun JSONObject.optionalString(name: String): String? =
        if (isNull(name)) null else optString(name).takeIf(String::isNotBlank)

    private fun JSONArray?.objects(): List<JSONObject> =
        (0 until (this?.length() ?: 0)).mapNotNull { index -> this?.optJSONObject(index) }

    private fun JSONArray?.strings(): Set<String> =
        (0 until (this?.length() ?: 0)).mapNotNullTo(linkedSetOf()) { index ->
            this?.optString(index)?.takeIf(String::isNotBlank)
        }
}

class DeviceAdministrationViewModel(
    private val principal: AuthenticatedPrincipal?,
    private val gateway: DeviceAdministrationGateway = DeviceAdministrationGateway(),
) : ViewModel() {
    private val mutableState = MutableStateFlow<DeviceAdministrationState>(DeviceAdministrationState.Loading)
    val state: StateFlow<DeviceAdministrationState> = mutableState

    init {
        if (principal == null || !DeviceAdministrationPolicy.canView(principal.permissionCodes)) {
            mutableState.value = DeviceAdministrationState.AccessDenied("No tiene permiso para consultar dispositivos.")
        } else {
            load()
        }
    }

    fun retry() = load()

    fun selectDevice(deviceId: String) {
        val ready = mutableState.value as? DeviceAdministrationState.Ready ?: return
        val device = ready.catalog.devices.firstOrNull { it.id == deviceId } ?: return
        mutableState.value = ready.copy(
            draft = DeviceEditorDraft(
                deviceId = device.id,
                name = device.name,
                state = device.state,
                voiceEnabled = device.voiceEnabled,
                branchId = device.branchId.orEmpty(),
                usageType = device.usageType,
                departmentIds = device.departmentIds,
            ),
            message = "",
        )
    }

    fun dismissEditor() {
        val ready = mutableState.value as? DeviceAdministrationState.Ready ?: return
        if (!ready.saving) mutableState.value = ready.copy(draft = null, message = "")
    }

    fun setName(value: String) = updateDraft { copy(name = value.take(80)) }
    fun setVoiceEnabled(value: Boolean) = updateDraft { copy(voiceEnabled = value) }
    fun setState(active: Boolean) = updateDraft { copy(state = if (active) "activo" else "inactivo") }
    fun setReason(value: String) = updateDraft { copy(reason = value.take(500)) }

    fun setBranch(branchId: String) = updateDraft {
        if (this.branchId == branchId) this else copy(branchId = branchId, departmentIds = emptySet())
    }

    fun setUsageType(value: String) = updateDraft {
        copy(
            usageType = value,
            departmentIds = DeviceAdministrationPolicy.departmentsFor(value, departmentIds),
        )
    }

    fun toggleDepartment(departmentId: String) = updateDraft {
        copy(
            departmentIds = if (departmentId in departmentIds) {
                departmentIds - departmentId
            } else {
                departmentIds + departmentId
            },
        )
    }

    fun save() {
        val authenticated = principal ?: return deny()
        if (!DeviceAdministrationPolicy.canManage(authenticated.permissionCodes)) return deny()
        val ready = mutableState.value as? DeviceAdministrationState.Ready ?: return
        val draft = ready.draft ?: return
        val error = DeviceAdministrationPolicy.validationMessage(draft, ready.catalog)
        if (error != null) {
            mutableState.value = ready.copy(message = error)
            return
        }
        if (ready.saving) return
        mutableState.value = ready.copy(saving = true, message = "Guardando configuración...")
        viewModelScope.launch {
            try {
                gateway.update(authenticated, draft)
                val refreshed = gateway.load(authenticated)
                mutableState.value = DeviceAdministrationState.Ready(
                    catalog = refreshed,
                    canManage = DeviceAdministrationPolicy.canManage(authenticated.permissionCodes),
                    message = "Terminal actualizado y listo para sincronizar.",
                )
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                mutableState.value = ready.copy(
                    saving = false,
                    message = error.message ?: "No fue posible actualizar el terminal.",
                )
            }
        }
    }

    private fun load() {
        val authenticated = principal ?: return deny()
        if (!DeviceAdministrationPolicy.canView(authenticated.permissionCodes)) return deny()
        mutableState.value = DeviceAdministrationState.Loading
        viewModelScope.launch {
            mutableState.value = try {
                DeviceAdministrationState.Ready(
                    catalog = gateway.load(authenticated),
                    canManage = DeviceAdministrationPolicy.canManage(authenticated.permissionCodes),
                )
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                DeviceAdministrationState.Error(error.message ?: "No fue posible cargar los dispositivos.")
            }
        }
    }

    private fun updateDraft(transform: DeviceEditorDraft.() -> DeviceEditorDraft) {
        val ready = mutableState.value as? DeviceAdministrationState.Ready ?: return
        if (ready.saving || ready.draft == null) return
        mutableState.value = ready.copy(draft = ready.draft.transform(), message = "")
    }

    private fun deny() {
        mutableState.value = DeviceAdministrationState.AccessDenied("No tiene permiso para administrar dispositivos.")
    }
}

class DeviceAdministrationViewModelFactory(
    private val principal: AuthenticatedPrincipal?,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        DeviceAdministrationViewModel(principal) as T
}

@Composable
fun DeviceAdministrationScreen(
    viewModel: DeviceAdministrationViewModel,
    canOpenLocalTerminal: Boolean,
    onOpenLocalTerminal: () -> Unit,
    onBack: () -> Unit,
) {
    val state by viewModel.state.collectAsState()

    Column(
        modifier = Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Dispositivos", style = MaterialTheme.typography.headlineMedium, fontWeight = FontWeight.Bold)
        Text("Terminales Android de la empresa. La autorización y el alcance se validan nuevamente en el servidor.")

        when (val current = state) {
            DeviceAdministrationState.Loading -> CircularProgressIndicator()
            is DeviceAdministrationState.AccessDenied -> Text(current.message, color = MaterialTheme.colorScheme.error)
            is DeviceAdministrationState.Error -> {
                Text(current.message, color = MaterialTheme.colorScheme.error)
                Button(onClick = viewModel::retry) { Text("Reintentar") }
            }
            is DeviceAdministrationState.Ready -> {
                val activeDevices = current.catalog.devices.filterNot(ManagedAndroidDevice::retired)
                val retiredDevices = current.catalog.devices.filter(ManagedAndroidDevice::retired)

                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Dispositivos registrados", style = MaterialTheme.typography.titleMedium)
                        Text("${current.catalog.devices.size} visibles en su alcance")
                        Text("${activeDevices.count { it.state == "activo" }} activos · ${activeDevices.count { it.state == "inactivo" }} inactivos")
                    }
                }

                Text("Terminales faciales", style = MaterialTheme.typography.titleLarge)
                if (activeDevices.isEmpty()) {
                    Text("No hay terminales faciales visibles en su alcance.")
                } else {
                    activeDevices.forEach { device ->
                        DeviceAdministrationCard(device = device, onClick = { viewModel.selectDevice(device.id) })
                    }
                }

                Text("Dispositivos retirados", style = MaterialTheme.typography.titleLarge)
                if (retiredDevices.isEmpty()) {
                    Text("No hay dispositivos retirados en su alcance.")
                } else {
                    retiredDevices.forEach { device ->
                        DeviceAdministrationCard(device = device, onClick = { viewModel.selectDevice(device.id) })
                    }
                }

                if (canOpenLocalTerminal) {
                    OutlinedButton(onClick = onOpenLocalTerminal, modifier = Modifier.fillMaxWidth()) {
                        Text("Abrir configuración local de este Android")
                    }
                }
                if (current.message.isNotBlank()) {
                    Text(
                        current.message,
                        color = if (current.message.startsWith("Terminal actualizado")) {
                            MaterialTheme.colorScheme.primary
                        } else {
                            MaterialTheme.colorScheme.error
                        },
                    )
                }
                current.draft?.let { draft ->
                    val device = current.catalog.devices.firstOrNull { it.id == draft.deviceId }
                    if (device != null) {
                        DeviceEditorDialog(
                            device = device,
                            draft = draft,
                            catalog = current.catalog,
                            canEdit = current.canManage && !device.retired,
                            saving = current.saving,
                            message = current.message,
                            viewModel = viewModel,
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(4.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Volver") }
    }
}

@Composable
private fun DeviceAdministrationCard(device: ManagedAndroidDevice, onClick: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onClick),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant),
    ) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(5.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(device.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
                Text(device.state.uppercase(), style = MaterialTheme.typography.labelMedium)
            }
            Text(listOf(device.model, "Android ${device.androidVersion}", "App ${device.appVersion}").filter(String::isNotBlank).joinToString(" · "))
            Text("Sucursal: ${device.branchName.ifBlank { "Sin asignar" }}")
            Text("Tipo: ${device.usageType} · Revisión ${device.configurationRevision}")
            Text("Última conexión: ${visibleTimestamp(device.lastConnectionAt)}", style = MaterialTheme.typography.bodySmall)
            Text("Tocar para ${if (device.retired) "consultar" else "configurar"}", style = MaterialTheme.typography.labelMedium)
        }
    }
}

@Composable
private fun DeviceEditorDialog(
    device: ManagedAndroidDevice,
    draft: DeviceEditorDraft,
    catalog: DeviceAdministrationCatalog,
    canEdit: Boolean,
    saving: Boolean,
    message: String,
    viewModel: DeviceAdministrationViewModel,
) {
    val enabled = canEdit && !saving
    val departments = catalog.departments.filter { it.branchId == draft.branchId && it.active }
    AlertDialog(
        onDismissRequest = viewModel::dismissEditor,
        title = { Text(if (device.retired) "Dispositivo retirado" else "Configurar terminal facial") },
        text = {
            Column(
                modifier = Modifier.fillMaxWidth().heightIn(max = 560.dp).verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                OutlinedTextField(
                    value = draft.name,
                    onValueChange = viewModel::setName,
                    label = { Text("Nombre") },
                    enabled = enabled,
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Text("Modelo: ${device.model.ifBlank { "No informado" }}")
                Text("Última conexión: ${visibleTimestamp(device.lastConnectionAt)}")

                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Voz", style = MaterialTheme.typography.titleSmall)
                        Text("Reproducir mensajes de voz en este terminal", style = MaterialTheme.typography.bodySmall)
                    }
                    Switch(checked = draft.voiceEnabled, onCheckedChange = viewModel::setVoiceEnabled, enabled = enabled)
                }

                Text("Sucursal", style = MaterialTheme.typography.titleSmall)
                catalog.branches.filter { it.active || it.id == draft.branchId }.forEach { branch ->
                    OutlinedButton(
                        onClick = { viewModel.setBranch(branch.id) },
                        enabled = enabled && branch.active,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(if (branch.id == draft.branchId) "Seleccionada: ${branch.name}" else branch.name)
                    }
                }

                Text("Tipo de terminal", style = MaterialTheme.typography.titleSmall)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(
                        onClick = { viewModel.setUsageType("GENERAL") },
                        enabled = enabled,
                        modifier = Modifier.weight(1f),
                    ) { Text(if (draft.usageType == "GENERAL") "GENERAL (activo)" else "GENERAL") }
                    OutlinedButton(
                        onClick = { viewModel.setUsageType("DEPARTMENTS") },
                        enabled = enabled,
                        modifier = Modifier.weight(1f),
                    ) { Text(if (draft.usageType == "DEPARTMENTS") "DEPARTAMENTOS (activo)" else "DEPARTAMENTOS") }
                }

                if (draft.usageType == "DEPARTMENTS") {
                    Text("Departamentos", style = MaterialTheme.typography.titleSmall)
                    if (departments.isEmpty()) Text("No hay departamentos activos disponibles en esta sucursal.")
                    departments.forEach { department ->
                        Row(
                            modifier = Modifier.fillMaxWidth().clickable(enabled = enabled) {
                                viewModel.toggleDepartment(department.id)
                            },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Checkbox(
                                checked = department.id in draft.departmentIds,
                                onCheckedChange = { viewModel.toggleDepartment(department.id) },
                                enabled = enabled,
                            )
                            Text(department.name)
                        }
                    }
                }

                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("Terminal activo", style = MaterialTheme.typography.titleSmall)
                        Text("Un terminal inactivo no sincroniza ni registra jornadas.", style = MaterialTheme.typography.bodySmall)
                    }
                    Switch(
                        checked = draft.state == "activo",
                        onCheckedChange = viewModel::setState,
                        enabled = enabled,
                    )
                }

                OutlinedTextField(
                    value = draft.reason,
                    onValueChange = viewModel::setReason,
                    label = { Text("Motivo del cambio") },
                    enabled = enabled,
                    minLines = 2,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (message.isNotBlank()) {
                    Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
                if (!canEdit) Text("Consulta solamente. No tiene permiso para modificar este terminal.")
                if (saving) CircularProgressIndicator()
            }
        },
        confirmButton = {
            if (canEdit) Button(onClick = viewModel::save, enabled = !saving) { Text("Guardar") }
        },
        dismissButton = {
            TextButton(onClick = viewModel::dismissEditor, enabled = !saving) { Text("Cerrar") }
        },
    )
}

private fun visibleTimestamp(value: String?): String = value
    ?.replace('T', ' ')
    ?.take(19)
    ?.takeIf(String::isNotBlank)
    ?: "Sin conexión registrada"