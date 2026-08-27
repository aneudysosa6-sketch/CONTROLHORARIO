package com.example.controlhorario.device

import android.util.Log
import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import com.example.controlhorario.model.EmployeeCodePolicy
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class EmployeeUploadResult(
 val key:String,val result:String,val remoteId:String?,val updatedAt:String?,
 val employeeCode:String?,val error:String?
)
internal object EmployeeUploadAuthorityPolicy {
 fun authoritativeCode(operation:String,remoteEmployeeCode:String?):String? =
  if(operation=="CREATE")remoteEmployeeCode?.let(EmployeeCodePolicy::normalizeOrNull) else null

 fun accepts(operation:String,remoteEmployeeCode:String?):Boolean =
  operation!="CREATE"||authoritativeCode(operation,remoteEmployeeCode)!=null
}
class EmployeeUploadHttpException(val status:Int,val body:String):Exception("employee-upsert HTTP $status")
class EmployeeUploadClient(private val endpoint:String){
 fun upload(deviceId:String,credential:String,items:List<EmployeeSyncOutboxEntity>):List<EmployeeUploadResult>{
  require(endpoint.startsWith("https://")&&endpoint.endsWith("/functions/v1/employee-upsert"))
  val connection=(URL(endpoint).openConnection() as HttpURLConnection).apply{requestMethod="POST";connectTimeout=15_000;readTimeout=25_000;doOutput=true;setRequestProperty("Content-Type","application/json");setRequestProperty("x-device-id",deviceId);setRequestProperty("x-device-credential",credential)}
  try{val operations=JSONArray().apply{items.forEach{item->
   val operation=JSONObject(item.payloadJson)
   operation.remove("pin")
   operation.remove("pin_hash")
   if(item.operation=="CREATE"){
    // Supabase owns allocation; even historical queued CREATE rows must not propose a code.
    operation.remove("employee_code")
   }else{
    val code=requireNotNull(EmployeeCodePolicy.normalizeOrNull(operation.optString("employee_code"))){EmployeeCodePolicy.ERROR}
    operation.put("employee_code",code)
   }
   put(operation)
  }};for(index in 0 until operations.length()){val operation=operations.getJSONObject(index);val embedding=operation.optJSONArray("face_embedding");if(embedding!=null)Log.d("FACE_EMBEDDING_FLOW","stage=http_request employeeId=${operation.optInt("local_employee_id")} faceEmbeddingType=array dimension=${embedding.length()} endpoint=$endpoint")};val body=JSONObject().put("operations",operations).toString();connection.outputStream.use{it.write(body.toByteArray())};val status=connection.responseCode;val response=(if(status in 200..299)connection.inputStream else connection.errorStream)?.bufferedReader()?.use{it.readText()}.orEmpty();Log.d("FACE_EMBEDDING_FLOW","stage=http_response status=$status operations=${items.size}");if(status !in 200..299)throw EmployeeUploadHttpException(status,response);val rows=JSONObject(response).getJSONArray("results");return(0 until rows.length()).map{rows.getJSONObject(it)}.map{EmployeeUploadResult(key=it.optString("idempotency_key"),result=it.optString("result"),remoteId=it.optString("remote_id").takeIf(String::isNotBlank),updatedAt=it.optString("updated_at").takeIf(String::isNotBlank),employeeCode=it.optString("employee_code").takeIf(String::isNotBlank)?.let(EmployeeCodePolicy::normalizeOrNull),error=it.optString("error_code").takeIf(String::isNotBlank))}}finally{connection.disconnect()}
 }
}
