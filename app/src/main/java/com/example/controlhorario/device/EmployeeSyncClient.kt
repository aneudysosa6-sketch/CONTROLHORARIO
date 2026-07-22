package com.example.controlhorario.device

import android.os.SystemClock
import android.util.Log
import com.example.controlhorario.model.EmployeeCodePolicy
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class EmployeeSyncCursor(val updatedAt:String,val id:String)
data class RemoteEmployee(
 val id:String,val code:String,val name:String,val phone:String,val email:String,
 val branchId:String?,val branchName:String,val departmentId:String?,val departmentName:String,
 val positionId:String?,val positionName:String,val supervisorId:String?,val supervisorName:String,
 val status:String,val jornadaEnabled:Boolean=true,val scheduleStart:String?=null,val scheduleEnd:String?=null,val lunchStart:String?=null,val lunchDurationMinutes:Int?=null,val workDays:String?=null,val toleranceMinutes:Int?=null,val startDate:String?,val salary:Double?,val payType:String?,val updatedAt:String,val faceEmbedding:FloatArray?=null,
 val remoteEmbeddingPresent:Boolean=false,val remoteEmbeddingDimension:Int?=null,
 val remoteEmbeddingValid:Boolean=faceEmbedding!=null
)
data class RemoteInactiveEmployee(
 val id:String,
 val updatedAt:String,
 val status:String="desvinculado",
 val jornadaEnabled:Boolean=false,
 val profileId:String?=null
)
data class RemoteKioskSettings(
 val companyId:String,val faceOnlyEnabled:Boolean,val pinFallbackEnabled:Boolean,
 val faceMatchThreshold:Float,val faceMatchMargin:Float?,val updatedAt:String
)
data class EmployeeSyncPage(
 val employees:List<RemoteEmployee>,val inactive:List<RemoteInactiveEmployee>,
 val cursor:EmployeeSyncCursor?,val hasMore:Boolean,val syncedAt:String,val httpStatus:Int=200,
 val companyId:String?=null,val deviceBranchId:String?=null,val companySettings:RemoteKioskSettings?=null
)

class EmployeeSyncClient(private val endpoint:String){
 fun download(deviceId:String,credential:String,cursor:EmployeeSyncCursor?,employeeCode:String?=null):EmployeeSyncPage{
  require(endpoint.startsWith("https://")&&endpoint.endsWith("/functions/v1/employee-sync")){"Configura CONTROLHORARIO_EMPLOYEE_SYNC_URL con HTTPS"}
  val normalizedEmployeeCode=employeeCode?.let{
   requireNotNull(EmployeeCodePolicy.normalizeOrNull(it)){EmployeeCodePolicy.ERROR}
  }
  val request=JSONObject()
  if(normalizedEmployeeCode!=null)request.put("employee_code",normalizedEmployeeCode)
  else cursor?.let{request.put("cursor",JSONObject().put("updated_at",it.updatedAt).put("id",it.id))}
  Log.d(TAG,"URL: $endpoint")
  Log.d(TAG,"company_id: pendiente de respuesta Edge; cursor enviado: updated_at=${cursor?.updatedAt}, id=${cursor?.id}")
  val startedAt=SystemClock.elapsedRealtime();var connection:HttpURLConnection?=null;var status=-1
  try{
   connection=(URL(endpoint).openConnection() as HttpURLConnection).apply{
    requestMethod="POST";connectTimeout=15000;readTimeout=20000;doOutput=true
    setRequestProperty("Content-Type","application/json");setRequestProperty("x-device-id",deviceId);setRequestProperty("x-device-credential",credential)
   }
   connection.outputStream.use{it.write(request.toString().toByteArray())}
   status=connection.responseCode
   val stream=if(status in 200..299)connection.inputStream else connection.errorStream
   val response=stream?.bufferedReader()?.use{it.readText()}.orEmpty()
   Log.d(TAG,"HTTP: $status en ${SystemClock.elapsedRealtime()-startedAt} ms")
   val json=runCatching{JSONObject(response)}.getOrElse{throw IllegalStateException("Respuesta inválida de employee-sync",it)}
   Log.d(TAG,"company_id: ${json.optString("company_id","<no devuelto>")}; diagnostic_request_id: ${json.optString("diagnostic_request_id","<no devuelto>")}")
   if(status !in 200..299)throw DeviceEnrollmentHttpException(status,response,json.optString("error","Error de sincronización"))
   return parse(json,status).also{
    Log.d(TAG,"empleados recibidos: activos=${it.employees.size}, inactivos=${it.inactive.size}, cursor=${it.cursor}, hasMore=${it.hasMore}")
    if(normalizedEmployeeCode!=null){val remote=it.employees.firstOrNull();Log.d("FACE_CROSS_DEVICE_SYNC","employeeCode=${EmployeeCodePolicy.maskForLog(normalizedEmployeeCode)} remoteId=${remote?.id} HTTP status=$status remoteEmbeddingPresent=${remote?.remoteEmbeddingPresent==true} remoteEmbeddingDimension=${remote?.remoteEmbeddingDimension} finalResult=${if(remote==null)"NOT_FOUND" else "DOWNLOADED"}")}
   }
  }catch(error:Exception){Log.e(TAG,"excepción completa employee-sync (URL=$endpoint, HTTP=$status, cursor=$cursor)",error);throw error}finally{connection?.disconnect()}
 }

 private fun parse(json:JSONObject,httpStatus:Int):EmployeeSyncPage{
  val employeeRows=json.optJSONArray("employees")
  val employees=(0 until (employeeRows?.length()?:0)).map{employeeRows!!.getJSONObject(it)}.map{row->
   val rawEmbedding=row.optJSONArray("face_embedding")
   val parsedEmbedding=rawEmbedding?.takeIf{it.length()==128}?.let{values->FloatArray(128){index->values.optDouble(index,Double.NaN).toFloat()}.takeIf{it.all(Float::isFinite)}}
   val remoteEmbeddingPresent=if(row.has("face_embedding_present"))row.optBoolean("face_embedding_present") else rawEmbedding!=null
   val remoteEmbeddingDimension=if(row.has("face_embedding_dimension")&&!row.isNull("face_embedding_dimension"))row.optInt("face_embedding_dimension") else rawEmbedding?.length()
   val remoteEmbeddingValid=if(row.has("face_embedding_valid"))row.optBoolean("face_embedding_valid") else parsedEmbedding!=null
   RemoteEmployee(
    id=row.getString("remote_id"),code=requireNotNull(EmployeeCodePolicy.normalizeOrNull(row.getString("code"))){"employee_sync_invalid_employee_code"},name=row.getString("name"),phone=row.optString("phone"),email=row.optString("email"),
    branchId=row.optNullableString("branch_id"),branchName=row.optString("branch_name"),departmentId=row.optNullableString("department_id"),departmentName=row.optString("department_name"),
    positionId=row.optNullableString("position_id"),positionName=row.optString("position_name"),supervisorId=row.optNullableString("supervisor_id"),supervisorName=row.optString("supervisor_name"),
    status=row.optString("status"),jornadaEnabled=row.optBoolean("jornada_enabled",true),scheduleStart=row.optNullableString("schedule_start"),scheduleEnd=row.optNullableString("schedule_end"),lunchStart=row.optNullableString("lunch_start"),lunchDurationMinutes=if(row.isNull("lunch_duration_minutes"))null else row.optInt("lunch_duration_minutes"),workDays=row.optJSONArray("work_days")?.let{days->(0 until days.length()).joinToString(","){index->days.getInt(index).toString()}},toleranceMinutes=if(row.isNull("tolerance_minutes"))null else row.optInt("tolerance_minutes"),startDate=row.optNullableString("start_date"),salary=if(row.isNull("salary"))null else row.getDouble("salary"),payType=row.optNullableString("pay_type"),updatedAt=row.getString("updated_at"),faceEmbedding=parsedEmbedding,remoteEmbeddingPresent=remoteEmbeddingPresent,remoteEmbeddingDimension=remoteEmbeddingDimension,remoteEmbeddingValid=remoteEmbeddingValid
   )
  }
  val inactiveRows=json.optJSONArray("inactive")
  val inactive=(0 until (inactiveRows?.length()?:0)).map{inactiveRows!!.getJSONObject(it)}.map{
   RemoteInactiveEmployee(
    id=it.getString("remote_id"),
    updatedAt=it.getString("updated_at"),
    status=it.optString("status","desvinculado").ifBlank{"desvinculado"},
    jornadaEnabled=it.optBoolean("jornada_enabled",false),
    profileId=it.optString("profile_id").takeIf(String::isNotBlank)
   )
  }
  val cursorJson=json.optJSONObject("cursor")
  val cursor=cursorJson?.optString("updated_at")?.takeIf{it.isNotBlank()}?.let{EmployeeSyncCursor(it,cursorJson.optString("id"))}
  val settingsJson=json.optJSONObject("company_settings")
  val companyId=json.optNullableString("company_id")?.takeIf{UUID_REGEX.matches(it)}
  val deviceBranchId=json.optNullableString("device_branch_id")?.takeIf{UUID_REGEX.matches(it)}
  val companySettings=settingsJson?.let{settings->
   val threshold=settings.optDouble("face_match_threshold",Double.NaN).toFloat()
   val margin=if(settings.isNull("face_match_margin"))null else settings.optDouble("face_match_margin",Double.NaN).toFloat()
   if(companyId==null||!threshold.isFinite()||threshold !in 0f..1f||margin?.let{!it.isFinite()||it !in 0f..2f}==true)null
   else RemoteKioskSettings(
    companyId=companyId,faceOnlyEnabled=settings.optBoolean("face_only_enabled",true),
    // Prefer the employee-code name; keep the old wire key only for rolling deployments.
    pinFallbackEnabled=if(settings.has("employee_code_fallback_enabled"))
     settings.optBoolean("employee_code_fallback_enabled",true)
    else settings.optBoolean("pin_fallback_enabled",true),faceMatchThreshold=threshold,
    faceMatchMargin=margin,updatedAt=settings.optString("updated_at")
   )
  }
  return EmployeeSyncPage(employees,inactive,cursor,json.optBoolean("has_more"),json.optString("synced_at"),httpStatus,companyId,deviceBranchId,companySettings)
 }
 private fun JSONObject.optNullableString(name:String)=if(isNull(name))null else optString(name).takeIf{it.isNotBlank()}
 private companion object{const val TAG="EmployeeSync";val UUID_REGEX=Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89aAbB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")}
}
