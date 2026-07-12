package com.example.controlhorario.device

import android.os.Build
import com.example.controlhorario.security.DeviceIdentityManager
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class EnrollmentResult(val deviceId:String,val credential:String,val expiresAt:String)
data class RemoteEmployee(val id:String,val code:String,val name:String,val phone:String,val active:Boolean,val branchId:String?,val updatedAt:String?)

class DeviceEnrollmentClient(private val endpoint:String){
 fun enroll(code:String,identity:DeviceIdentityManager):EnrollmentResult{
  val body=JSONObject().put("action","exchange").put("code",code.trim().uppercase())
   .put("installation_id",identity.installationId).put("public_key_spki",identity.publicKeySpkiBase64())
   .put("name","OSINET Android").put("model",Build.MODEL).put("android_version",Build.VERSION.RELEASE).put("app_version","1.0")
  val json=post(body)
  return EnrollmentResult(json.getString("device_id"),json.getString("credential"),json.getString("expires_at"))
 }
 fun employees(deviceId:String,credential:String):List<RemoteEmployee>{
  val json=post(JSONObject().put("action","employee-sync"),mapOf("x-device-id" to deviceId,"x-device-credential" to credential))
  val rows=json.optJSONArray("employees")?:JSONArray()
  return (0 until rows.length()).map{rows.getJSONObject(it)}.map{row->RemoteEmployee(row.getString("id"),row.getString("codigo_empleado"),row.getString("nombre_completo"),row.optString("telefono"),row.optBoolean("activo"),row.optString("sucursal_id").takeIf{it.isNotBlank()&&it!="null"},row.optString("updated_at").takeIf{it.isNotBlank()})}
 }
 private fun post(body:JSONObject,headers:Map<String,String> = emptyMap()):JSONObject{
  require(endpoint.startsWith("https://")){"Configura CONTROLHORARIO_DEVICE_ENROLLMENT_URL con HTTPS"}
  val connection=(URL(endpoint).openConnection() as HttpURLConnection).apply{requestMethod="POST";connectTimeout=15000;readTimeout=20000;doOutput=true;setRequestProperty("Content-Type","application/json");headers.forEach(::setRequestProperty)}
  connection.outputStream.use{it.write(body.toString().toByteArray())}
  val status=connection.responseCode;val stream=if(status in 200..299)connection.inputStream else connection.errorStream
  val response=stream?.bufferedReader()?.use{it.readText()}.orEmpty();connection.disconnect()
  val json=runCatching{JSONObject(response)}.getOrElse{throw IllegalStateException("Respuesta inválida del servidor")}
  if(status !in 200..299)throw IllegalStateException(json.optString("error","No fue posible registrar el dispositivo"))
  return json
 }
}
