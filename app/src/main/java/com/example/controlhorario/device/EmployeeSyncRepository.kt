package com.example.controlhorario.device

import androidx.room.withTransaction
import android.util.Log
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.model.Employee

data class EmployeeSyncSummary(val downloaded:Int,val activated:Int,val deactivated:Int,val syncedAt:Long)

class EmployeeSyncRepository(private val database:AppDatabase){
 suspend fun sync(client:EmployeeSyncClient,deviceId:String,credential:String):EmployeeSyncSummary{
  val enrollment=database.deviceEnrollmentDao().current()
  var cursor=enrollment?.employeeSyncCursorUpdatedAt?.let{EmployeeSyncCursor(it,enrollment.employeeSyncCursorId.orEmpty())}
  var downloaded=0;var activated=0;var deactivated=0;var inserted=0;var updated=0;var discarded=0
  Log.d(TAG,"Room sync inicio: device_id=$deviceId, cursor=$cursor, last_sync=${enrollment?.lastEmployeeSyncAt}")
  do{
   val page=client.download(deviceId,credential,cursor);val syncedAt=System.currentTimeMillis()
   Log.d(TAG,"Room recibe página: activos=${page.employees.size}, inactivos=${page.inactive.size}, cursor_respuesta=${page.cursor}")
   database.withTransaction{
    val dao=database.employeeDao()
    page.employees.forEach{row->
     val remoteMatch=dao.findByRemoteId(row.id);val codeMatch=if(remoteMatch==null)dao.findAnyByEmployeeCode(row.code)else null;val current=remoteMatch?:codeMatch
     if(current?.remoteUpdatedAt==null||current.remoteUpdatedAt<=row.updatedAt){
      val value=EmployeeSyncMapper.merge(current,row,syncedAt)
      if(current==null){dao.insertEmployee(value);inserted++;Log.d(TAG,"insertado remote_id=${row.id}, code=${row.code}")}else{dao.updateEmployee(value);updated++;Log.d(TAG,"actualizado remote_id=${row.id}, local_id=${current.id}, match=${if(remoteMatch!=null)"remote_id" else "code"}")}
      if(current?.isActive!=true)activated++
     }else{discarded++;Log.w(TAG,"descartado remote_id=${row.id}: updated_at remoto ${row.updatedAt} no supera local ${current.remoteUpdatedAt}")}
    }
    page.inactive.forEach{row->
     val current=dao.findByRemoteId(row.id)
     if(current!=null&&(current.remoteUpdatedAt==null||current.remoteUpdatedAt<=row.updatedAt)){
      dao.updateEmployee(EmployeeSyncMapper.mergeInactive(current,row,syncedAt))
      updated++;Log.d(TAG,"actualizado inactivo remote_id=${row.id}, local_id=${current.id}")
      if(current.isActive)deactivated++
     }else{discarded++;Log.w(TAG,"descartado tombstone remote_id=${row.id}: ${if(current==null)"no existe en Room" else "updated_at remoto ${row.updatedAt} no supera local ${current.remoteUpdatedAt}"}")}
    }
    downloaded+=page.employees.size+page.inactive.size
   }
   cursor=page.cursor
  }while(page.hasMore)
  val completedAt=System.currentTimeMillis()
  database.deviceEnrollmentDao().recordEmployeeSync(deviceId,completedAt,cursor?.updatedAt,cursor?.id)
  Log.d(TAG,"Room sync final: recibidos=$downloaded, insertados=$inserted, actualizados=$updated, descartados=$discarded, activados=$activated, desactivados=$deactivated, cursor_guardado=$cursor")
  return EmployeeSyncSummary(downloaded,activated,deactivated,completedAt)
 }
 private companion object{const val TAG="EmployeeSync"}
}

object EmployeeSyncMapper{
 fun merge(current:Employee?,row:RemoteEmployee,syncedAt:Long):Employee=
  (current?:Employee(employeeCode=row.code,pin="")).copy(
   employeeCode=row.code,nombre=row.name,telefono=row.phone,email=row.email,cargo=row.positionName,departamento=row.departmentName,
   sueldo=row.salary?:0.0,isActive=true,remoteId=row.id,remoteBranchId=row.branchId,remoteBranchName=row.branchName,
   remoteDepartmentId=row.departmentId,remoteDepartmentName=row.departmentName,remotePositionId=row.positionId,remotePositionName=row.positionName,
   remoteSupervisorId=row.supervisorId,remoteSupervisorName=row.supervisorName,employmentStatus=row.status,jornadaEnabled=row.jornadaEnabled,startDate=row.startDate,payType=row.payType,
   remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt
  )
 fun mergeInactive(current:Employee,row:RemoteInactiveEmployee,syncedAt:Long)=current.copy(isActive=false,employmentStatus="desvinculado",remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt)
}
