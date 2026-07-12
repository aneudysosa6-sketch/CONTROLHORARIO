package com.example.controlhorario.device

import android.os.SystemClock
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

data class EmployeeSyncCursor(val updatedAt:String,val id:String)
data class RemoteEmployee(
 val id:String,val code:String,val name:String,val phone:String,val email:String,
 val branchId:String?,val branchName:String,val departmentId:String?,val departmentName:String,
 val positionId:String?,val positionName:String,val supervisorId:String?,val supervisorName:String,
 val status:String,val startDate:String?,val salary:Double?,val payType:String?,val updatedAt:String
)
data class RemoteInactiveEmployee(val id:String,val updatedAt:String)
data class EmployeeSyncPage(
 val employees:List<RemoteEmployee>,val inactive:List<RemoteInactiveEmployee>,
 val cursor:EmployeeSyncCursor?,val hasMore:Boolean,val syncedAt:String
)

class EmployeeSyncClient(private val endpoint:String){
 fun download(deviceId:String,credential:String,cursor:EmployeeSyncCursor?):EmployeeSyncPage{
  require(endpoint.startsWith("https://")&&endpoint.endsWith("/functions/v1/employee-sync")){"Configura CONTROLHORARIO_EMPLOYEE_SYNC_URL con HTTPS"}
  val request=JSONObject()
  cursor?.let{request.put("cursor",JSONObject().put("updated_at",it.updatedAt).put("id",it.id))}
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
   Log.d(TAG,"employee-sync HTTP $status en ${SystemClock.elapsedRealtime()-startedAt} ms")
   val json=runCatching{JSONObject(response)}.getOrElse{throw IllegalStateException("Respuesta inválida de employee-sync",it)}
   if(status !in 200..299)throw DeviceEnrollmentHttpException(status,response,json.optString("error","Error de sincronización"))
   return parse(json)
  }catch(error:Exception){Log.e(TAG,"employee-sync falló (HTTP $status)",error);throw error}finally{connection?.disconnect()}
 }

 private fun parse(json:JSONObject):EmployeeSyncPage{
  val employeeRows=json.optJSONArray("employees")
  val employees=(0 until (employeeRows?.length()?:0)).map{employeeRows!!.getJSONObject(it)}.map{row->
   RemoteEmployee(
    id=row.getString("remote_id"),code=row.getString("code"),name=row.getString("name"),phone=row.optString("phone"),email=row.optString("email"),
    branchId=row.optNullableString("branch_id"),branchName=row.optString("branch_name"),departmentId=row.optNullableString("department_id"),departmentName=row.optString("department_name"),
    positionId=row.optNullableString("position_id"),positionName=row.optString("position_name"),supervisorId=row.optNullableString("supervisor_id"),supervisorName=row.optString("supervisor_name"),
    status=row.optString("status"),startDate=row.optNullableString("start_date"),salary=if(row.isNull("salary"))null else row.getDouble("salary"),payType=row.optNullableString("pay_type"),updatedAt=row.getString("updated_at")
   )
  }
  val inactiveRows=json.optJSONArray("inactive")
  val inactive=(0 until (inactiveRows?.length()?:0)).map{inactiveRows!!.getJSONObject(it)}.map{RemoteInactiveEmployee(it.getString("remote_id"),it.getString("updated_at"))}
  val cursorJson=json.optJSONObject("cursor")
  val cursor=cursorJson?.optString("updated_at")?.takeIf{it.isNotBlank()}?.let{EmployeeSyncCursor(it,cursorJson.optString("id"))}
  return EmployeeSyncPage(employees,inactive,cursor,json.optBoolean("has_more"),json.optString("synced_at"))
 }
 private fun JSONObject.optNullableString(name:String)=if(isNull(name))null else optString(name).takeIf{it.isNotBlank()}
 private companion object{const val TAG="EmployeeSync"}
}
