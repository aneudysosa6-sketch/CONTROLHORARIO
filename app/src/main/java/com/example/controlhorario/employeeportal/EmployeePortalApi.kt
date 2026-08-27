package com.example.controlhorario.employeeportal

import com.example.controlhorario.BuildConfig
import com.example.controlhorario.auth.AuthenticatedPrincipal
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class EmployeePortalPayload(val json:JSONObject){val profile:JSONObject get()=json.getJSONObject("perfil");val earnings:JSONObject get()=json.getJSONObject("ganancias")}
class EmployeePortalApi(private val principal:AuthenticatedPrincipal){
 suspend fun load()=withContext(Dispatchers.IO){EmployeePortalPayload(rpc("obtener_portal_empleado",JSONObject()))}
 suspend fun requestLoan(amount:Double,discount:Double,reason:String,idempotency:String)=withContext(Dispatchers.IO){rpc("crear_solicitud_prestamo",JSONObject().put("p_monto",amount).put("p_descuento",discount).put("p_motivo",reason).put("p_idempotency",idempotency).put("p_origen","ANDROID"))}
 private fun rpc(name:String,body:JSONObject):JSONObject{var connection:HttpURLConnection?=null;try{connection=(URL("${BuildConfig.SUPABASE_URL}/rest/v1/rpc/$name").openConnection()as HttpURLConnection).apply{requestMethod="POST";connectTimeout=15_000;readTimeout=25_000;doOutput=true;setRequestProperty("apikey",BuildConfig.SUPABASE_PUBLISHABLE_KEY);setRequestProperty("Authorization","Bearer ${principal.accessToken}");setRequestProperty("Content-Type","application/json");setRequestProperty("Accept","application/json");outputStream.use{it.write(body.toString().toByteArray())}};val status=connection.responseCode;val text=(if(status in 200..299)connection.inputStream else connection.errorStream)?.bufferedReader()?.use{it.readText()}.orEmpty();if(status !in 200..299){val error=runCatching{JSONObject(text)}.getOrNull();throw IllegalStateException(error?.optString("message")?.takeIf{it.isNotBlank()}?:"Supabase devolvió HTTP $status")};return JSONObject(text)}finally{connection?.disconnect()}}
}
