package com.example.controlhorario.auth

import com.example.controlhorario.BuildConfig
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

interface SupabaseAuthGateway {
    suspend fun signInWithPassword(email: String, password: String): SupabaseSession
    suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile
}

class SupabaseAuthApi(
    private val baseUrl: String = BuildConfig.SUPABASE_URL,
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) : SupabaseAuthGateway {
    override suspend fun signInWithPassword(email: String, password: String): SupabaseSession {
        val response = request(
            method = "POST",
            path = "/auth/v1/token?grant_type=password",
            body = JSONObject().put("email", email).put("password", password).toString(),
            stage = "supabase_auth",
        )
        val json = JSONObject(response)
        val token = json.optString("access_token")
        val user = json.optJSONObject("user")
            ?: throw AuthFlowException("supabase_auth", message = "Supabase Auth no devolvió el usuario autenticado.")
        val uid = user.optString("id")
        if (token.isBlank() || uid.isBlank()) throw AuthFlowException("supabase_auth", message = "Supabase Auth no devolvió una sesión válida.")
        return SupabaseSession(token, uid, user.optString("email", email))
    }

    override suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile {
        val profileRows = rows(
            table = "profiles",
            select = "id,company_id,status,full_name,role_id",
            filters = listOf("id" to "eq.${session.authUid}"),
            token = session.accessToken,
            stage = "profile",
        )
        val profile = profileRows.optJSONObject(0)
            ?: throw AuthFlowException("profile", code = "PROFILE_NOT_FOUND", message = "La cuenta Auth no tiene un profile empresarial.")
        if (profile.optString("status") != "active") throw AuthFlowException("profile", code = "PROFILE_INACTIVE", message = "El profile está inactivo.")
        val companyId = profile.optString("company_id")
        val roleId = profile.optString("role_id")
        if (companyId.isBlank() || roleId.isBlank()) throw AuthFlowException("profile", code = "PROFILE_INCOMPLETE", message = "El profile no contiene empresa y rol válidos.")

        val roleRows = rows(
            table = "roles",
            select = "id,name,code,is_active",
            filters = listOf("id" to "eq.$roleId", "company_id" to "eq.$companyId"),
            token = session.accessToken,
            stage = "role",
        )
        val role = roleRows.optJSONObject(0)
            ?: throw AuthFlowException("role", code = "ROLE_NOT_FOUND", message = "El profile no tiene un rol válido dentro de su empresa.")
        if (!role.optBoolean("is_active")) throw AuthFlowException("role", code = "ROLE_INACTIVE", message = "El rol asignado está inactivo.")

        val roleAssignments = rows("rol_permisos", "permiso_id,permitido", listOf("rol_id" to "eq.$roleId"), session.accessToken, "role_permissions")
        val profileAssignments = rows("perfil_permisos", "permiso_id,permitido", listOf("perfil_id" to "eq.${session.authUid}"), session.accessToken, "profile_permissions")
        val assignmentRows = buildList {
            repeat(roleAssignments.length()) { add(roleAssignments.getJSONObject(it)) }
            repeat(profileAssignments.length()) { add(profileAssignments.getJSONObject(it)) }
        }
        val ids = assignmentRows.mapNotNull { it.optString("permiso_id").takeIf(String::isNotBlank) }.distinct()
        val codeById = if (ids.isEmpty()) emptyMap() else {
            val catalog = rows("permisos", "id,codigo", listOf("id" to "in.(${ids.joinToString(",")})", "activo" to "eq.true"), session.accessToken, "permission_catalog")
            buildMap { repeat(catalog.length()) { val row = catalog.getJSONObject(it); put(row.optString("id"), row.optString("codigo")) } }
        }
        val effective = linkedMapOf<String, Boolean>()
        repeat(roleAssignments.length()) { val row = roleAssignments.getJSONObject(it); codeById[row.optString("permiso_id")]?.let { effective[it] = row.optBoolean("permitido") } }
        repeat(profileAssignments.length()) { val row = profileAssignments.getJSONObject(it); codeById[row.optString("permiso_id")]?.let { effective[it] = row.optBoolean("permitido") } }
        val permissions = effective.filterValues { it }.keys
        if ("portal.acceder" !in permissions) throw AuthFlowException("permissions", code = "PORTAL_ACCESS_DENIED", message = "La cuenta no tiene permiso para acceder al portal.")
        return AuthorizedProfile(
            authUid = session.authUid,
            email = session.email,
            companyId = companyId,
            roleId = roleId,
            roleCode = role.optString("code"),
            roleName = role.optString("name"),
            fullName = profile.optString("full_name"),
            permissionCodes = permissions,
        )
    }

    private fun rows(table: String, select: String, filters: List<Pair<String, String>>, token: String, stage: String): JSONArray {
        val query = buildList {
            add("select=${encode(select)}")
            filters.forEach { (key, value) -> add("${encode(key)}=${encode(value)}") }
        }.joinToString("&")
        return JSONArray(request("GET", "/rest/v1/$table?$query", token = token, stage = stage))
    }

    private fun request(method: String, path: String, body: String? = null, token: String? = null, stage: String): String {
        var connection: HttpURLConnection? = null
        try {
            connection = (URL("$baseUrl$path").openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15_000
                readTimeout = 25_000
                setRequestProperty("apikey", publishableKey)
                setRequestProperty("Accept", "application/json")
                if (token != null) setRequestProperty("Authorization", "Bearer $token")
                if (body != null) { doOutput = true; setRequestProperty("Content-Type", "application/json"); outputStream.use { it.write(body.toByteArray()) } }
            }
            val status = connection.responseCode
            val response = (if (status in 200..299) connection.inputStream else connection.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            if (status !in 200..299) throw parseFailure(stage, status, response)
            return response
        } catch (error: AuthFlowException) {
            throw error
        } catch (error: Exception) {
            throw AuthFlowException(stage, code = "NETWORK_ERROR", message = error.message ?: "Error de red.", cause = error)
        } finally { connection?.disconnect() }
    }

    private fun parseFailure(stage: String, status: Int, body: String): AuthFlowException {
        val json = runCatching { JSONObject(body) }.getOrNull()
        val code = json?.optString("code")?.takeIf(String::isNotBlank)
            ?: json?.optString("error_code")?.takeIf(String::isNotBlank)
            ?: "HTTP_$status"
        val message = listOf("msg", "message", "error_description", "error").firstNotNullOfOrNull { key -> json?.optString(key)?.takeIf(String::isNotBlank) }
            ?: "Supabase devolvió HTTP $status."
        return AuthFlowException(stage, code, message, json?.optString("details")?.takeIf(String::isNotBlank), json?.optString("hint")?.takeIf(String::isNotBlank))
    }

    private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())
}
