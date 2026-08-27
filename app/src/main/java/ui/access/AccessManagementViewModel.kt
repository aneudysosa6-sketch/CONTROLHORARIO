package com.example.controlhorario.ui.access

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.auth.AuthenticatedPrincipal
import com.example.controlhorario.auth.SupabaseRuntimeConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.text.Charsets

interface AccessManagementGateway {
    suspend fun load(): AccessCatalog
    suspend fun create(request: CreateAccessRequest)
    suspend fun update(request: UpdateAccessRequest)
    suspend fun updatePassword(profileId: String, password: String)
    suspend fun setStatus(profileId: String, status: String)
    suspend fun delete(profileId: String)
}

class UserProvisioningGateway(
    private val principal: AuthenticatedPrincipal,
    baseUrl: String = BuildConfig.SUPABASE_URL,
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) : AccessManagementGateway {
    private val config = SupabaseRuntimeConfig.validate(baseUrl, publishableKey)
    private val endpoint = "${config.baseUrl}/functions/v1/user-provisioning"

    override suspend fun load(): AccessCatalog = withContext(Dispatchers.IO) {
        parseCatalog(request(JSONObject().put("action", "list-accesses")))
    }

    override suspend fun create(request: CreateAccessRequest) {
        mutate(
            JSONObject()
                .put("action", "create-access")
                .put("employee_id", request.employeeId)
                .put("username", request.username.trim())
                .put("password", request.password)
                .put("role_id", request.roleId)
                .put("status", request.status)
        )
    }

    override suspend fun update(request: UpdateAccessRequest) {
        mutate(
            JSONObject()
                .put("action", "update-access")
                .put("profile_id", request.profileId)
                .put("employee_id", request.employeeId)
                .put("username", request.username.trim())
                .put("role_id", request.roleId)
                .put("status", request.status)
        )
    }

    override suspend fun updatePassword(profileId: String, password: String) {
        mutate(JSONObject().put("action", "update-password").put("profile_id", profileId).put("password", password))
    }

    override suspend fun setStatus(profileId: String, status: String) {
        mutate(JSONObject().put("action", "set-status").put("profile_id", profileId).put("status", status))
    }

    override suspend fun delete(profileId: String) {
        mutate(JSONObject().put("action", "delete-access").put("profile_id", profileId))
    }

    private suspend fun mutate(body: JSONObject) = withContext(Dispatchers.IO) { request(body); Unit }

    private fun request(body: JSONObject): String {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 15_000
            readTimeout = 25_000
            doOutput = true
            setRequestProperty("apikey", publishableKey)
            setRequestProperty("Authorization", "Bearer ${principal.accessToken}")
            setRequestProperty("Content-Type", "application/json")
            setRequestProperty("Accept", "application/json")
        }
        return try {
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
            val status = connection.responseCode
            val response = (if (status in 200..299) connection.inputStream else connection.errorStream)
                ?.bufferedReader(Charsets.UTF_8)?.use { it.readText() }.orEmpty()
            if (status !in 200..299) {
                val error = runCatching { JSONObject(response) }.getOrNull()
                val message = error?.optString("error")?.takeIf(String::isNotBlank)
                    ?: error?.optString("message")?.takeIf(String::isNotBlank)
                    ?: "No fue posible completar la operación de acceso (HTTP $status)."
                throw AccessServiceException(
                    statusCode = status,
                    message = message,
                )
            }
            response
        } finally {
            connection.disconnect()
        }
    }

    private fun parseCatalog(body: String): AccessCatalog {
        val root = JSONObject(body)
        val roles = root.optJSONArray("roles").orEmpty().mapObjects { row ->
            AccessRole(
                id = row.requiredId("id"),
                name = row.optString("name"),
                code = row.optString("code"),
                companyId = row.optString("company_id"),
            )
        }
        val roleById = roles.associateBy(AccessRole::id)
        val employees = root.optJSONArray("employees").orEmpty().mapObjects { row ->
            AccessEmployee(
                id = row.requiredId("id"),
                fullName = row.optString("nombre_completo"),
                employeeCode = row.optString("codigo_empleado"),
                companyId = row.optString("empresa_id"),
                isActive = row.optBoolean("activo"),
                profileId = row.nullableId("perfil_id"),
            )
        }
        val accesses = root.optJSONArray("accesses").orEmpty().mapObjects { row ->
            val roleId = row.requiredId("role_id")
            AccessAccount(
                id = row.requiredId("id"),
                username = row.optString("username"),
                email = row.optString("email").takeUnless { it.isBlank() || it == "null" },
                employeeId = row.nullableId("employee_id").orEmpty(),
                employeeName = row.optString("employee_name"),
                employeeCode = row.optString("employee_code"),
                roleId = roleId,
                roleName = row.optString("role_name").ifBlank { roleById[roleId]?.name.orEmpty() },
                roleCode = roleById[roleId]?.code.orEmpty(),
                status = row.optString("status", ACCESS_STATUS_INACTIVE).lowercase(),
                lastSignInAt = row.optString("last_sign_in_at").takeUnless { it.isBlank() || it == "null" },
            )
        }
        return AccessCatalog(accesses = accesses, employees = employees, roles = roles)
    }

    private fun JSONObject.requiredId(key: String): String = nullableId(key)
        ?: throw IllegalStateException("La respuesta de Accesos no contiene '$key'.")

    private fun JSONObject.nullableId(key: String): String? = optString(key)
        .takeUnless { it.isBlank() || it == "null" }

    private fun JSONArray?.orEmpty(): JSONArray = this ?: JSONArray()

    private inline fun <T> JSONArray.mapObjects(block: (JSONObject) -> T): List<T> =
        buildList { repeat(length()) { add(block(getJSONObject(it))) } }
}

data class AccessManagementUiState(
    val catalog: AccessCatalog? = null,
    val catalogLoadState: AccessCatalogLoadState = AccessCatalogLoadState.LOADING,
    val loading: Boolean = true,
    val busy: Boolean = false,
    val message: String = "",
    val error: String = "",
)

class AccessManagementViewModel(
    private val currentProfileId: String,
    private val currentCompanyId: String,
    private val capabilities: AccessCapabilities,
    private val gateway: AccessManagementGateway,
) : ViewModel() {
    private val mutableState = MutableStateFlow(AccessManagementUiState())
    val state: StateFlow<AccessManagementUiState> = mutableState

    init { refresh() }

    fun refresh() {
        if (!capabilities.canView) return reject(AccessPolicyDecision.denied("No tienes permiso para consultar accesos."))
        if (mutableState.value.busy) return
        viewModelScope.launch {
            mutableState.value = mutableState.value.copy(
                loading = true,
                catalogLoadState = AccessCatalogLoadState.LOADING,
                error = "",
                message = "",
            )
            mutableState.value = runCatching { gateway.load() }
                .fold(
                    onSuccess = { catalog ->
                        logCatalogLoad(catalog)
                        mutableState.value.copy(
                            catalog = catalog,
                            catalogLoadState = AccessCatalogLoadState.READY,
                            loading = false,
                        )
                    },
                    onFailure = {
                        if (BuildConfig.DEBUG) {
                            val state = stateErrorType(it)
                            Log.e("AccessManagement", "No fue posible cargar empleados. company_id=$currentCompanyId state=$state", it)
                        }
                        val loadState = stateErrorType(it)
                        mutableState.value.copy(
                            loading = false,
                            catalogLoadState = loadState,
                            error = if (loadState == AccessCatalogLoadState.ERROR_QUERY) it.visibleMessage() else "",
                        )
                    },
                )
        }
    }

    fun create(request: CreateAccessRequest) {
        if (!capabilities.canCreate) return reject(AccessPolicyDecision.denied("No tienes permiso para crear accesos."))
        val catalog = mutableState.value.catalog ?: return
        val decision = AccessManagementPolicy.validateCreate(request, catalog)
        if (!decision.allowed) return reject(decision)
        mutate("Acceso creado correctamente.") { gateway.create(request) }
    }

    fun update(request: UpdateAccessRequest) {
        if (!capabilities.canEdit) return reject(AccessPolicyDecision.denied("No tienes permiso para editar accesos."))
        val catalog = mutableState.value.catalog ?: return
        val decision = AccessManagementPolicy.validateUpdate(request, catalog, currentProfileId)
        if (!decision.allowed) return reject(decision)
        mutate("Acceso actualizado correctamente.") { gateway.update(request) }
    }

    fun changePassword(profileId: String, password: String) {
        if (!capabilities.canManage) return reject(AccessPolicyDecision.denied("No tienes permiso para cambiar contraseñas."))
        val decision = AccessManagementPolicy.validatePassword(password)
        if (!decision.allowed) return reject(decision)
        mutate("Contraseña actualizada correctamente.") { gateway.updatePassword(profileId, password) }
    }

    fun setStatus(target: AccessAccount, status: String) {
        if (!capabilities.canManage) return reject(AccessPolicyDecision.denied("No tienes permiso para cambiar el estado."))
        val catalog = mutableState.value.catalog ?: return
        val decision = AccessManagementPolicy.canSetStatus(target, status, currentProfileId, catalog.accesses)
        if (!decision.allowed) return reject(decision)
        mutate(if (status == ACCESS_STATUS_ACTIVE) "Acceso activado." else "Acceso desactivado.") {
            gateway.setStatus(target.id, status)
        }
    }

    fun delete(target: AccessAccount) {
        if (!capabilities.canManage) return reject(AccessPolicyDecision.denied("No tienes permiso para eliminar accesos."))
        val catalog = mutableState.value.catalog ?: return
        val decision = AccessManagementPolicy.canDelete(target, currentProfileId, catalog.accesses)
        if (!decision.allowed) return reject(decision)
        mutate("Acceso eliminado. El empleado se conservó intacto.") { gateway.delete(target.id) }
    }

    fun clearFeedback() {
        mutableState.value = mutableState.value.copy(message = "", error = "")
    }

    private fun reject(decision: AccessPolicyDecision) {
        mutableState.value = mutableState.value.copy(error = decision.message.orEmpty(), message = "")
    }

    private fun mutate(successMessage: String, operation: suspend () -> Unit) {
        if (mutableState.value.busy) return
        viewModelScope.launch {
            mutableState.value = mutableState.value.copy(busy = true, error = "", message = "")
            try {
                operation()
                val fresh = gateway.load()
                mutableState.value = mutableState.value.copy(
                    catalog = fresh,
                    loading = false,
                    catalogLoadState = AccessCatalogLoadState.READY,
                    busy = false,
                    message = successMessage,
                )
                logCatalogLoad(fresh)
            } catch (error: Exception) {
                mutableState.value = mutableState.value.copy(busy = false, error = error.visibleMessage())
            }
        }
    }

    private fun logCatalogLoad(catalog: AccessCatalog) {
        if (!BuildConfig.DEBUG) return
        val activeEmployees = catalog.employees.count { it.isActive }
        val activeEmployeesWithoutProfile = catalog.employees.count { it.isActive && it.profileId.isNullOrBlank() }
        val activeEmployeesExcludedByProfile = catalog.employees.count { it.isActive && it.profileId?.isNotBlank() == true }
        Log.d(
            "AccessManagement",
            "company_id=$currentCompanyId employees=${catalog.employees.size} active_employees=$activeEmployees " +
                "available_employees=$activeEmployeesWithoutProfile excluded_with_profile=$activeEmployeesExcludedByProfile " +
                "accesses=${catalog.accesses.size}",
        )
    }

    private fun stateErrorType(error: Throwable): AccessCatalogLoadState {
        val statusCode = (error as? AccessServiceException)?.statusCode
        val message = error.message.orEmpty().lowercase()
        return when {
            statusCode == 403 && message.contains("permiso") -> AccessCatalogLoadState.ERROR_PERMISSION
            statusCode == 403 && message.contains("profile activo requerido") -> AccessCatalogLoadState.ERROR_COMPANY_MISSING
            statusCode == 401 -> AccessCatalogLoadState.ERROR_COMPANY_MISSING
            message.contains("no se pudo determinar la empresa activa") -> AccessCatalogLoadState.ERROR_COMPANY_MISSING
            else -> AccessCatalogLoadState.ERROR_QUERY
        }
    }

    private fun Throwable.visibleMessage(): String = message?.takeIf(String::isNotBlank)
        ?: "No fue posible completar la operación de acceso."
}

private class AccessServiceException(
    val statusCode: Int,
    override val message: String,
) : Exception(message)

enum class AccessCatalogLoadState(val userMessage: String?) {
    LOADING("Cargando empleados"),
    READY(null),
    ERROR_QUERY("No fue posible cargar los empleados. Inténtalo nuevamente."),
    ERROR_PERMISSION("No tienes permisos para consultar los empleados de esta empresa."),
    ERROR_COMPANY_MISSING("No se pudo determinar la empresa activa."),
}

class AccessManagementViewModelFactory(
    private val principal: AuthenticatedPrincipal,
    private val gateway: AccessManagementGateway = UserProvisioningGateway(principal),
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T =
        AccessManagementViewModel(
            currentProfileId = principal.authUid,
            currentCompanyId = principal.companyId,
            capabilities = AccessCapabilities.from(principal.permissionCodes),
            gateway = gateway,
        ) as T
}
