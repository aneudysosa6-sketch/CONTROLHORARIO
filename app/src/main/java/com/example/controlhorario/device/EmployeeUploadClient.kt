package com.example.controlhorario.device

import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class EmployeeUploadResult(val key:String,val result:String,val remoteId:String?,val updatedAt:String?,val error:String?)
class EmployeeUploadHttpException(val status:Int,val body:String):Exception("employee-upsert HTTP $status: ${body.take(240)}")
class EmployeeUploadClient(private val endpoint:String){
 fun upload(deviceId:String,credential:String,items:List<EmployeeSyncOutboxEntity>):List<EmployeeUploadResult>{
  require(endpoint.startsWith("https://")&&endpoint.endsWith("/functions/v1/employee-upsert"))
  val connection=(URL(endpoint).openConnection() as HttpURLConnection).apply{requestMethod="POST";connectTimeout=15_000;readTimeout=25_000;doOutput=true;setRequestProperty("Content-Type","application/json");setRequestProperty("x-device-id",deviceId);setRequestProperty("x-device-credential",credential)}
  try{val body=JSONObject().put("operations",JSONArray().apply{items.forEach{put(JSONObject(it.payloadJson))}}).toString();connection.outputStream.use{it.write(body.toByteArray())};val status=connection.responseCode;val response=(if(status in 200..299)connection.inputStream else connection.errorStream)?.bufferedReader()?.use{it.readText()}.orEmpty();if(status !in 200..299)throw EmployeeUploadHttpException(status,response);val rows=JSONObject(response).getJSONArray("results");return(0 until rows.length()).map{rows.getJSONObject(it)}.map{EmployeeUploadResult(it.optString("idempotency_key"),it.optString("result"),it.optString("remote_id").takeIf(String::isNotBlank),it.optString("updated_at").takeIf(String::isNotBlank),it.optString("error_code").takeIf(String::isNotBlank))}}finally{connection.disconnect()}
 }
}
