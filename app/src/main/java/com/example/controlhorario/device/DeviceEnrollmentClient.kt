package com.example.controlhorario.device

import android.os.Build
import android.os.SystemClock
import android.util.Log
import com.example.controlhorario.security.DeviceIdentityManager
import org.json.JSONObject
import java.io.IOException
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import java.net.UnknownHostException
import javax.net.ssl.SSLException

data class EnrollmentResult(val deviceId:String,val credential:String,val expiresAt:String)

class DeviceEnrollmentHttpException(
 val statusCode:Int,
 val responseBody:String,
 val edgeFunctionMessage:String
):IllegalStateException("HTTP $statusCode: $edgeFunctionMessage")

internal fun deviceEnrollmentErrorMessage(error:Throwable):String{
 val cause=generateSequence(error){it.cause}.toList()
 val http=cause.filterIsInstance<DeviceEnrollmentHttpException>().firstOrNull()
 val edge=http?.edgeFunctionMessage.orEmpty()
 val normalized=edge.lowercase()
 return when{
  cause.any{it is SSLException}->"Error TLS al conectar con el servidor."
  cause.any{it is UnknownHostException}->"Error DNS: no se pudo localizar el servidor."
  cause.any{it is SocketTimeoutException}->"Error de red: el servidor tardó demasiado en responder."
  cause.any{it is ConnectException}->"Error de red: no se pudo conectar con el servidor."
  "ya registrado" in normalized||"already registered" in normalized->"Dispositivo ya registrado."
  "expir" in normalized||"vencid" in normalized->if("inválid" in normalized||"invalid" in normalized||"usado" in normalized) "Código inválido, expirado o ya utilizado." else "Código expirado."
  "ya utilizado" in normalized||"usado" in normalized||"already used" in normalized->"Código ya utilizado."
  "código" in normalized&&("inválid" in normalized||"invalid" in normalized)->"Código inválido."
  http!=null&&edge.isNotBlank()->"Error ${http.statusCode}: $edge"
  http!=null->"Error HTTP ${http.statusCode}."
  cause.any{it is IOException}->"Error de red: ${error.message?:"conexión fallida"}."
  else->error.message?.takeIf{it.isNotBlank()}?:"No fue posible registrar el dispositivo."
 }
}

class DeviceEnrollmentClient(private val endpoint:String){
 fun enroll(code:String,identity:DeviceIdentityManager):EnrollmentResult{
  val body=JSONObject().put("action","exchange").put("code",code.trim().uppercase())
   .put("installation_id",identity.installationId).put("public_key_spki",identity.publicKeySpkiBase64())
   .put("name","OSINET Android").put("model",Build.MODEL).put("android_version",Build.VERSION.RELEASE).put("app_version","1.0")
  val json=post(body)
  return EnrollmentResult(json.getString("device_id"),json.getString("credential"),json.getString("expires_at"))
 }
 private fun post(body:JSONObject,headers:Map<String,String> = emptyMap()):JSONObject{
  require(endpoint.startsWith("https://")){"Configura CONTROLHORARIO_DEVICE_ENROLLMENT_URL con HTTPS"}
  val startedAt=SystemClock.elapsedRealtime()
  var connection:HttpURLConnection?=null
  var statusCode=-1
  Log.d(TAG,"URL llamada: $endpoint")
  try{
   connection=(URL(endpoint).openConnection() as HttpURLConnection).apply{requestMethod="POST";connectTimeout=15000;readTimeout=20000;doOutput=true;setRequestProperty("Content-Type","application/json");headers.forEach(::setRequestProperty)}
   connection.outputStream.use{it.write(body.toString().toByteArray())}
   statusCode=connection.responseCode
   Log.d(TAG,"Código HTTP: $statusCode")
   val stream=if(statusCode in 200..299)connection.inputStream else connection.errorStream
   val response=stream?.bufferedReader()?.use{it.readText()}.orEmpty()
   Log.d(TAG,"Response Body completo: $response")
   val json=try{
    JSONObject(response).also{Log.d(TAG,"Resultado del parseo JSON: éxito: $it")}
   }catch(error:Exception){
    Log.e(TAG,"Resultado del parseo JSON: error",error)
    throw IllegalStateException("Respuesta inválida del servidor",error)
   }
   val edgeMessage=json.optString("error").trim()
   Log.d(TAG,"Mensaje devuelto por la Edge Function: ${edgeMessage.ifBlank{"<sin error>"}}")
   if(statusCode !in 200..299)throw DeviceEnrollmentHttpException(statusCode,response,edgeMessage.ifBlank{"Sin mensaje de error"})
   return json
  }catch(error:Exception){
   Log.e(TAG,"Exception durante device-enrollment (HTTP $statusCode)",error)
   throw error
  }finally{
   Log.d(TAG,"Tiempo de respuesta: ${SystemClock.elapsedRealtime()-startedAt} ms")
   connection?.disconnect()
  }
 }
 private companion object{const val TAG="DeviceEnrollment"}
}
