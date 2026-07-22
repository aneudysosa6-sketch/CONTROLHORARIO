package com.example.controlhorario.ui.administration

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.database.KioskSettingsEntity
import com.example.controlhorario.repository.KioskFaceAuthSettings
import com.example.controlhorario.repository.KioskSettingsRepository
import com.example.controlhorario.ui.punch.PinFallbackPolicy
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

sealed interface KioskFaceAuthAdminState {
    data object Loading : KioskFaceAuthAdminState
    data class Ready(val settings: KioskFaceAuthSettings, val saving: Boolean = false, val message: String = "") : KioskFaceAuthAdminState
    data class AccessDenied(val message: String) : KioskFaceAuthAdminState
    data class Error(val message: String) : KioskFaceAuthAdminState
}

class KioskFaceAuthAdminGateway(
    private val baseUrl: String = BuildConfig.SUPABASE_URL.trimEnd('/'),
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) {
    suspend fun load(principal: AuthenticatedPrincipal): KioskFaceAuthSettings = withContext(Dispatchers.IO) {
        val url = "$baseUrl/rest/v1/company_settings?select=company_id,face_only_enabled,pin_fallback_enabled,face_match_threshold,face_match_margin,updated_at&company_id=eq.${principal.companyId}&limit=1"
        val body = request("GET", url, principal.accessToken, null)
        val row = JSONArray(body).optJSONObject(0)
        if (row == null) {
            KioskSettingsRepository.defaults(principal.companyId, GLOBAL_DEVICE_SCOPE)
        } else {
            row.toSettings(GLOBAL_DEVICE_SCOPE)
        }
    }

    suspend fun update(
        principal: AuthenticatedPrincipal,
        settings: KioskFaceAuthSettings,
    ): KioskFaceAuthSettings = withContext(Dispatchers.IO) {
        val body = request(
            "POST",
            "$baseUrl/rest/v1/rpc/actualizar_configuracion_kiosk",
            principal.accessToken,
            JSONObject()
                .put("p_pin_fallback_enabled", settings.pinFallbackEnabled)
                .put("p_face_only_enabled", settings.faceOnlyEnabled)
                .put("p_face_match_threshold", settings.faceMatchThreshold.toDouble())
                .put("p_face_match_margin", settings.faceMatchMargin?.toDouble() ?: JSONObject.NULL)
                .toString(),
        )
        JSONObject(body).toSettings(GLOBAL_DEVICE_SCOPE)
    }

    private fun request(method: String, url: String, token: String, payload: String?): String {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = 15_000
            readTimeout = 20_000
            setRequestProperty("apikey", publishableKey)
            setRequestProperty("Authorization", "Bearer $token")
            setRequestProperty("Accept", "application/json")
            if (payload != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        return try {
            if (payload != null) connection.outputStream.use { it.write(payload.toByteArray()) }
            val status = connection.responseCode
            val body = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val error = runCatching { JSONObject(body) }.getOrNull()
                throw IllegalStateException(error?.optString("message")?.takeIf(String::isNotBlank) ?: "Supabase devolvió HTTP $status")
            }
            body
        } finally {
            connection.disconnect()
        }
    }

    private fun JSONObject.toSettings(deviceId: String) = KioskFaceAuthSettings(
        companyId = getString("company_id"),
        deviceId = deviceId,
        faceOnlyEnabled = optBoolean("face_only_enabled", true),
        pinFallbackEnabled = optBoolean("pin_fallback_enabled", true),
        faceMatchThreshold = optDouble("face_match_threshold", 0.75).toFloat(),
        faceMatchMargin = if (isNull("face_match_margin")) null else getDouble("face_match_margin").toFloat(),
        remoteUpdatedAt = optString("updated_at").takeIf(String::isNotBlank),
        lastSyncedAt = null,
    )

    companion object {
        const val GLOBAL_DEVICE_SCOPE = "company"
    }
}

class KioskFaceAuthAdminViewModel(
    private val principal: AuthenticatedPrincipal?,
    private val deviceId: String?,
    private val localRepository: KioskSettingsRepository,
    private val gateway: KioskFaceAuthAdminGateway = KioskFaceAuthAdminGateway(),
) : ViewModel() {
    private val mutableState = MutableStateFlow<KioskFaceAuthAdminState>(KioskFaceAuthAdminState.Loading)
    val state: StateFlow<KioskFaceAuthAdminState> = mutableState

    init { load() }

    fun setPinFallbackEnabled(enabled: Boolean) {
        val current = mutableState.value as? KioskFaceAuthAdminState.Ready ?: return
        save(current.settings.copy(pinFallbackEnabled = enabled))
    }

    fun setFaceOnlyEnabled(enabled: Boolean) {
        val current = mutableState.value as? KioskFaceAuthAdminState.Ready ?: return
        save(current.settings.copy(faceOnlyEnabled = enabled))
    }

    fun saveConfidence(thresholdText: String, marginText: String) {
        val current = mutableState.value as? KioskFaceAuthAdminState.Ready ?: return
        val threshold = thresholdText.trim().replace(',', '.').toFloatOrNull()
        val margin = marginText.trim().replace(',', '.').toFloatOrNull()
        if (threshold == null || margin == null) {
            mutableState.value = current.copy(message = "Ingrese umbral y margen numéricos medidos.")
            return
        }
        val valid = runCatching { KioskSettingsRepository.validate(threshold, margin) }.isSuccess
        if (!valid) {
            mutableState.value = current.copy(message = "El umbral debe estar entre 0 y 1 y el margen entre 0 y 2.")
            return
        }
        save(current.settings.copy(faceMatchThreshold = threshold, faceMatchMargin = margin))
    }

    private fun save(next: KioskFaceAuthSettings) {
        val authenticated = principal ?: return deny()
        if (!PinFallbackPolicy.canManage(authenticated.permissionCodes)) return deny()
        val current = mutableState.value as? KioskFaceAuthAdminState.Ready ?: return
        if (current.saving) return
        mutableState.value = current.copy(saving = true, message = "Guardando…")
        viewModelScope.launch {
            try {
                PinFallbackPolicy.requireCanManage(authenticated.permissionCodes)
                val updated = gateway.update(authenticated, next)
                persistForThisDevice(updated)
                mutableState.value = KioskFaceAuthAdminState.Ready(updated, message = "Configuración guardada y lista para sincronizar.")
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                mutableState.value = KioskFaceAuthAdminState.Ready(current.settings, message = error.message ?: "No fue posible guardar la configuración.")
            }
        }
    }

    private fun load() {
        val authenticated = principal ?: return deny()
        if (!PinFallbackPolicy.canManage(authenticated.permissionCodes)) return deny()
        viewModelScope.launch {
            mutableState.value = try {
                val remote = gateway.load(authenticated)
                persistForThisDevice(remote)
                KioskFaceAuthAdminState.Ready(remote)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                KioskFaceAuthAdminState.Error(error.message ?: "No fue posible cargar la configuración del kiosco.")
            }
        }
    }

    private suspend fun persistForThisDevice(settings: KioskFaceAuthSettings) {
        val localDeviceId = deviceId ?: return
        localRepository.saveRemote(
            KioskSettingsEntity(
                companyId = settings.companyId,
                deviceId = localDeviceId,
                faceOnlyEnabled = settings.faceOnlyEnabled,
                pinFallbackEnabled = settings.pinFallbackEnabled,
                faceMatchThreshold = settings.faceMatchThreshold,
                faceMatchMargin = settings.faceMatchMargin,
                remoteUpdatedAt = settings.remoteUpdatedAt.orEmpty(),
                lastSyncedAt = System.currentTimeMillis(),
            )
        )
    }

    private fun deny() {
        mutableState.value = KioskFaceAuthAdminState.AccessDenied("No tiene el permiso kiosk.pin_fallback_manage.")
    }
}

class KioskFaceAuthAdminViewModelFactory(
    private val principal: AuthenticatedPrincipal?,
    private val deviceId: String?,
    private val localRepository: KioskSettingsRepository,
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        KioskFaceAuthAdminViewModel(principal, deviceId, localRepository) as T
}

@Composable
fun KioskFaceAuthAdminScreen(viewModel: KioskFaceAuthAdminViewModel, onBack: () -> Unit) {
    val state by viewModel.state.collectAsState()
    var thresholdText by remember { mutableStateOf("") }
    var marginText by remember { mutableStateOf("") }
    val ready = state as? KioskFaceAuthAdminState.Ready
    LaunchedEffect(ready?.settings?.faceMatchThreshold, ready?.settings?.faceMatchMargin) {
        ready?.settings?.let {
            thresholdText = it.faceMatchThreshold.toString()
            marginText = it.faceMatchMargin?.toString().orEmpty()
        }
    }
    Column(
        modifier = Modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        Text("Autenticación del kiosco", style = MaterialTheme.typography.headlineMedium)
        Text("El rostro siempre es obligatorio. El PIN solo identifica al empleado antes de verificar su rostro.")
        when (val current = state) {
            KioskFaceAuthAdminState.Loading -> CircularProgressIndicator()
            is KioskFaceAuthAdminState.AccessDenied -> Text(current.message, color = MaterialTheme.colorScheme.error)
            is KioskFaceAuthAdminState.Error -> {
                Text(current.message, color = MaterialTheme.colorScheme.error)
                Button(onClick = onBack) { Text("Volver") }
            }
            is KioskFaceAuthAdminState.Ready -> {
                Card(colors = CardDefaults.cardColors(containerColor = Color(0xFF101E33)), modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(18.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text("Identificación rostro primero", style = MaterialTheme.typography.titleMedium)
                                Text("Desactivarla inicia PIN + rostro.", style = MaterialTheme.typography.bodySmall)
                            }
                            Switch(
                                checked = current.settings.faceOnlyEnabled,
                                enabled = !current.saving,
                                onCheckedChange = viewModel::setFaceOnlyEnabled,
                            )
                        }
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Column(Modifier.weight(1f)) {
                                Text("Permitir PIN alternativo", style = MaterialTheme.typography.titleMedium)
                                Text("Solo aparece si el rostro no es concluyente.", style = MaterialTheme.typography.bodySmall)
                            }
                            Switch(
                                checked = current.settings.pinFallbackEnabled,
                                enabled = !current.saving,
                                onCheckedChange = viewModel::setPinFallbackEnabled,
                            )
                        }
                        Text("Parámetros medidos de confianza", style = MaterialTheme.typography.titleSmall)
                        OutlinedTextField(
                            value = thresholdText,
                            onValueChange = { thresholdText = it.take(8) },
                            label = { Text("Umbral coseno (0–1)") },
                            enabled = !current.saving,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                        OutlinedTextField(
                            value = marginText,
                            onValueChange = { marginText = it.take(8) },
                            label = { Text("Margen entre candidatos (0–2)") },
                            supportingText = { Text("Déjelo sin guardar hasta contar con una calibración medida.") },
                            enabled = !current.saving,
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Button(
                            onClick = { viewModel.saveConfidence(thresholdText, marginText) },
                            enabled = !current.saving,
                            modifier = Modifier.fillMaxWidth(),
                        ) { Text("Guardar parámetros calibrados") }
                        if (current.message.isNotBlank()) Text(current.message, style = MaterialTheme.typography.bodySmall)
                    }
                }
                if (current.saving) CircularProgressIndicator()
            }
        }
        Spacer(Modifier.height(4.dp))
        OutlinedButton(onClick = onBack, modifier = Modifier.fillMaxWidth()) { Text("Volver") }
    }
}
