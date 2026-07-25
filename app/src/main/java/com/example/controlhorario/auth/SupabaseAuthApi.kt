package com.example.controlhorario.auth

import com.example.controlhorario.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

interface SupabaseAuthGateway {
    suspend fun signInWithPassword(email: String, password: String): SupabaseSession
    suspend fun refreshSession(refreshToken: String, emailFallback: String = ""): SupabaseSession
    suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile
}

class SupabaseAuthApi(
    private val baseUrl: String = BuildConfig.SUPABASE_URL,
    private val publishableKey: String = BuildConfig.SUPABASE_PUBLISHABLE_KEY,
) : SupabaseAuthGateway {
    private val config = SupabaseRuntimeConfig.validate(baseUrl, publishableKey)

    override suspend fun signInWithPassword(email: String, password: String): SupabaseSession = withContext(Dispatchers.IO) {
        val response = request(
            method = "POST",
            path = "/auth/v1/token?grant_type=password",
            body = JSONObject().put("email", email).put("password", password).toString(),
            stage = "supabase_auth",
        )
        val json = JSONObject(response)
        parseSession(json, emailFallback = email, stage = "supabase_auth")
    }

    override suspend fun refreshSession(refreshToken: String, emailFallback: String): SupabaseSession = withContext(Dispatchers.IO) {
        val token = refreshToken.trim()
        if (token.isBlank()) throw AuthFlowException("supabase_auth", code = "REFRESH_TOKEN_MISSING", message = "No hay refresh_token para renovar la sesión.")
        val response = request(
            method = "POST",
            path = "/auth/v1/token?grant_type=refresh_token",
            body = JSONObject().put("refresh_token", token).toString(),
            stage = "refresh_session",
        )
        val json = JSONObject(response)
        parseSession(json, emailFallback = emailFallback, stage = "refresh_session")
    }

    override suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile = withContext(Dispatchers.IO) {
        val identity = resolveAuthIdentity(session)
        val profileRows = rows(
            table = "profiles",
            select = "id,company_id,status,full_name,role_id",
            filters = listOf("id" to "eq.${identity.userId}"),
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
        val profileAssignments = rows("perfil_permisos", "permiso_id,permitido", listOf("perfil_id" to "eq.${identity.userId}"), session.accessToken, "profile_permissions")
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
        AuthorizedProfile(
            authUid = identity.userId,
            email = identity.email,
            companyId = companyId,
            roleId = roleId,
            roleCode = role.optString("code"),
            roleName = role.optString("name"),
            fullName = profile.optString("full_name"),
            permissionCodes = permissions,
        )
    }

    private fun resolveAuthIdentity(session: SupabaseSession): AuthIdentity {
        val fallbackEmail = session.email.trim()
        if (session.authUid.isNotBlank() && fallbackEmail.isNotBlank()) {
            return AuthIdentity(
                userId = session.authUid,
                email = fallbackEmail,
            )
        }
        val body = request("GET", "/auth/v1/user", token = session.accessToken, stage = "auth_user")
        val user = runCatching { JSONObject(body) }.getOrNull() ?: throw AuthFlowException("auth_user", code = "AUTH_USER_ERROR", message = "No fue posible leer la sesiÃ³n del usuario desde Supabase.")
        val userId = user.optString("id").ifBlank { user.optJSONObject("user")?.optString("id") ?: "" }
        if (userId.isBlank()) throw AuthFlowException("auth_user", code = "AUTH_USER_ID_MISSING", message = "Supabase Auth no devolviÃ³ el identificador de usuario.")
        val userEmail = user.optString("email", fallbackEmail).ifBlank {
            user.optJSONObject("user")?.optString("email", "") ?: ""
        }
        if (userEmail.isBlank()) throw AuthFlowException("auth_user", code = "AUTH_USER_EMAIL_MISSING", message = "Supabase Auth no devolviÃ³ el correo del usuario.")
        return AuthIdentity(userId, userEmail)
    }

    private data class AuthIdentity(val userId: String, val email: String)

    private fun rows(table: String, select: String, filters: List<Pair<String, String>>, token: String, stage: String): JSONArray {
        val query = buildList {
            add("select=${encode(select)}")
            filters.forEach { (key, value) -> add("${encode(key)}=${encode(value)}") }
        }.joinToString("&")
        return JSONArray(request("GET", "/rest/v1/$table?$query", token = token, stage = stage))
    }

    private fun parseSession(response: JSONObject, emailFallback: String, stage: String): SupabaseSession {
        val accessToken = response.optString("access_token")
        val refreshToken = response.optString("refresh_token")
        val user = response.optJSONObject("user")
            ?: throw AuthFlowException(stage, message = "Supabase Auth no devolvió el usuario autenticado.")
        val uid = user.optString("id")
        val email = user.optString("email", emailFallback)
        val expiresAt = response.optLong("expires_at")
            .let { if (it > 0L) it * 1000L else 0L }
            .takeIf { it > 0L }
            ?: run {
                val seconds = response.optLong("expires_in", 0L)
                if (seconds > 0L) System.currentTimeMillis() + seconds * 1000L else 0L
            }
        if (accessToken.isBlank() || refreshToken.isBlank() || uid.isBlank() || email.isBlank()) {
            throw AuthFlowException(stage, message = "Supabase Auth no devolvió una sesión válida.")
        }
        return SupabaseSession(accessToken, refreshToken, expiresAt, uid, email)
    }

    private fun request(method: String, path: String, body: String? = null, token: String? = null, stage: String): String {
        var connection: HttpURLConnection? = null
        try {
            val fullUrl = "${config.baseUrl}$path"
            SafeHttpDiagnostics.request("AndroidAuth", method, fullUrl, config)
            connection = (URL(fullUrl).openConnection() as HttpURLConnection).apply {
                requestMethod = method
                connectTimeout = 15_000
                readTimeout = 25_000
                setRequestProperty("apikey", config.publishableKey)
                setRequestProperty("Accept", "application/json")
                if (token != null) setRequestProperty("Authorization", "Bearer $token")
                if (body != null) { doOutput = true; setRequestProperty("Content-Type", "application/json"); outputStream.use { it.write(body.toByteArray()) } }
            }
            val status = connection.responseCode
            val response = (if (status in 200..299) connection.inputStream else connection.errorStream)?.bufferedReader()?.use { it.readText() }.orEmpty()
            SafeHttpDiagnostics.response("AndroidAuth", status, response)
            if (status !in 200..299) throw parseFailure(stage, status, response)
            return response
        } catch (error: AuthFlowException) {
            throw error
        } catch (error: Exception) {
            val classified = SafeHttpDiagnostics.exception("AndroidAuth", stage, error)
            throw AuthFlowException(stage, code = classified.code, message = classified.message, cause = error)
        } finally { connection?.disconnect() }
    }

    private fun parseFailure(stage: String, status: Int, body: String): AuthFlowException {
        val json = runCatching { JSONObject(body) }.getOrNull()
        val code = json?.optString("error_code")?.takeIf(String::isNotBlank)
            ?: json?.optString("code")?.takeIf(String::isNotBlank)
            ?: "HTTP_$status"
        val message = listOf("msg", "message", "error_description", "error").firstNotNullOfOrNull { key -> json?.optString(key)?.takeIf(String::isNotBlank) }
            ?: "Supabase devolvió HTTP $status."
        return AuthFlowException(stage, code, message, json?.optString("details")?.takeIf(String::isNotBlank), json?.optString("hint")?.takeIf(String::isNotBlank))
    }

    private fun encode(value: String) = URLEncoder.encode(value, Charsets.UTF_8.name())
}
