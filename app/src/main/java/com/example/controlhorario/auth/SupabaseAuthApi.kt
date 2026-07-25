package com.example.controlhorario.auth

import com.example.controlhorario.BuildConfig
import java.net.HttpURLConnection
import java.net.URL
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

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

    override suspend fun signInWithPassword(email: String, password: String): SupabaseSession =
        withContext(Dispatchers.IO) {
            val response = request(
                method = "POST",
                path = "/auth/v1/token?grant_type=password",
                body = JSONObject().put("email", email).put("password", password).toString(),
                stage = "supabase_auth",
            )
            parseSession(JSONObject(response), emailFallback = email, stage = "supabase_auth")
        }

    override suspend fun refreshSession(
        refreshToken: String,
        emailFallback: String,
    ): SupabaseSession = withContext(Dispatchers.IO) {
        val token = refreshToken.trim()
        if (token.isBlank()) {
            throw AuthFlowException(
                "supabase_auth",
                code = "REFRESH_TOKEN_MISSING",
                message = "No hay refresh_token para renovar la sesion.",
            )
        }
        val response = request(
            method = "POST",
            path = "/auth/v1/token?grant_type=refresh_token",
            body = JSONObject().put("refresh_token", token).toString(),
            stage = "refresh_session",
        )
        parseSession(JSONObject(response), emailFallback, "refresh_session")
    }

    override suspend fun loadAuthorization(session: SupabaseSession): AuthorizedProfile =
        withContext(Dispatchers.IO) {
            val response = request(
                method = "POST",
                path = "/rest/v1/rpc/obtener_mi_autorizacion",
                body = "{}",
                token = session.accessToken,
                stage = "authorization",
            )
            val authorization = runCatching { JSONObject(response) }.getOrElse {
                throw AuthFlowException(
                    "authorization",
                    code = "AUTHORIZATION_INVALID_RESPONSE",
                    message = "Supabase devolvio una autorizacion invalida.",
                    cause = it,
                )
            }
            val permissions = authorization.stringSet("permission_codes")
            if ("portal.acceder" !in permissions) {
                throw AuthFlowException(
                    "permissions",
                    code = "PORTAL_ACCESS_DENIED",
                    message = "La cuenta no tiene permiso para acceder al portal.",
                )
            }
            AuthorizedProfile(
                authUid = authorization.requiredString("auth_user_id"),
                profileId = authorization.requiredString("profile_id"),
                employeeId = authorization.nullableString("employee_id"),
                email = authorization.optString("email"),
                companyId = authorization.requiredString("company_id"),
                roleId = authorization.requiredString("role_id"),
                roleCodeOriginal = authorization.requiredString("role_code_original"),
                roleCode = authorization.requiredString("role_code_canonical"),
                roleName = authorization.requiredString("role_name"),
                fullName = authorization.requiredString("nombre"),
                active = authorization.optBoolean("active"),
                permissionCodes = permissions,
                primaryDepartmentId = authorization.nullableString("departamento_principal_id"),
                additionalDepartmentIds = authorization.stringSet("departamentos_adicionales"),
                branchIds = authorization.stringSet("sucursales"),
                authorizationVersion = authorization.requiredString("authorization_version"),
            )
        }

    private fun JSONObject.requiredString(key: String): String =
        optString(key).takeIf(String::isNotBlank)
            ?: throw AuthFlowException(
                "authorization",
                code = "AUTHORIZATION_FIELD_MISSING",
                message = "La autorizacion no contiene $key.",
            )

    private fun JSONObject.nullableString(key: String): String? =
        if (isNull(key)) null else optString(key).takeIf(String::isNotBlank)

    private fun JSONObject.stringSet(key: String): Set<String> {
        val values = optJSONArray(key) ?: JSONArray()
        return buildSet {
            repeat(values.length()) {
                values.optString(it).takeIf(String::isNotBlank)?.let(::add)
            }
        }
    }

    private fun parseSession(
        response: JSONObject,
        emailFallback: String,
        stage: String,
    ): SupabaseSession {
        val accessToken = response.optString("access_token")
        val refreshToken = response.optString("refresh_token")
        val user = response.optJSONObject("user")
            ?: throw AuthFlowException(stage, message = "Supabase Auth no devolvio el usuario autenticado.")
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
            throw AuthFlowException(stage, message = "Supabase Auth no devolvio una sesion valida.")
        }
        return SupabaseSession(accessToken, refreshToken, expiresAt, uid, email)
    }

    private fun request(
        method: String,
        path: String,
        body: String? = null,
        token: String? = null,
        stage: String,
    ): String {
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
            SafeHttpDiagnostics.response("AndroidAuth", status, response)
            if (status !in 200..299) throw parseFailure(stage, status, response)
            return response
        } catch (error: AuthFlowException) {
            throw error
        } catch (error: Exception) {
            val classified = SafeHttpDiagnostics.exception("AndroidAuth", stage, error)
            throw AuthFlowException(
                stage,
                code = classified.code,
                message = classified.message,
                cause = error,
            )
        } finally {
            connection?.disconnect()
        }
    }

    private fun parseFailure(stage: String, status: Int, body: String): AuthFlowException {
        val json = runCatching { JSONObject(body) }.getOrNull()
        val code = json?.optString("error_code")?.takeIf(String::isNotBlank)
            ?: json?.optString("code")?.takeIf(String::isNotBlank)
            ?: "HTTP_$status"
        val message = listOf("msg", "message", "error_description", "error")
            .firstNotNullOfOrNull { key -> json?.optString(key)?.takeIf(String::isNotBlank) }
            ?: "Supabase devolvio HTTP $status."
        return AuthFlowException(
            stage,
            code,
            message,
            json?.optString("details")?.takeIf(String::isNotBlank),
            json?.optString("hint")?.takeIf(String::isNotBlank),
        )
    }
}
