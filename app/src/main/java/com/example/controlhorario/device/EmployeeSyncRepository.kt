package com.example.controlhorario.device

import androidx.room.withTransaction
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.model.Employee

data class EmployeeSyncSummary(val downloaded:Int,val activated:Int,val deactivated:Int,val syncedAt:Long)

class EmployeeSyncRepository(private val database:AppDatabase){
 suspend fun sync(client:EmployeeSyncClient,deviceId:String,credential:String):EmployeeSyncSummary{
  val enrollment=database.deviceEnrollmentDao().current()
  var cursor=enrollment?.employeeSyncCursorUpdatedAt?.let{EmployeeSyncCursor(it,enrollment.employeeSyncCursorId.orEmpty())}
  var downloaded=0;var activated=0;var deactivated=0
  do{
   val page=client.download(deviceId,credential,cursor);val syncedAt=System.currentTimeMillis()
   database.withTransaction{
    val dao=database.employeeDao()
    page.employees.forEach{row->
     val current=dao.findByRemoteId(row.id)?:dao.findAnyByEmployeeCode(row.code)
     if(current?.remoteUpdatedAt==null||current.remoteUpdatedAt<=row.updatedAt){
      val value=EmployeeSyncMapper.merge(current,row,syncedAt)
      if(current==null)dao.insertEmployee(value)else dao.updateEmployee(value)
      if(current?.isActive!=true)activated++
     }
    }
    page.inactive.forEach{row->
     val current=dao.findByRemoteId(row.id)
     if(current!=null&&(current.remoteUpdatedAt==null||current.remoteUpdatedAt<=row.updatedAt)){
      dao.updateEmployee(EmployeeSyncMapper.mergeInactive(current,row,syncedAt))
      if(current.isActive)deactivated++
     }
    }
    downloaded+=page.employees.size+page.inactive.size
   }
   cursor=page.cursor
  }while(page.hasMore)
  val completedAt=System.currentTimeMillis()
  database.deviceEnrollmentDao().recordEmployeeSync(deviceId,completedAt,cursor?.updatedAt,cursor?.id)
  return EmployeeSyncSummary(downloaded,activated,deactivated,completedAt)
 }
}

object EmployeeSyncMapper{
 fun merge(current:Employee?,row:RemoteEmployee,syncedAt:Long):Employee=
  (current?:Employee(employeeCode=row.code,pin="")).copy(
   employeeCode=row.code,nombre=row.name,telefono=row.phone,email=row.email,cargo=row.positionName,departamento=row.departmentName,
   sueldo=row.salary?:0.0,isActive=true,remoteId=row.id,remoteBranchId=row.branchId,remoteBranchName=row.branchName,
   remoteDepartmentId=row.departmentId,remoteDepartmentName=row.departmentName,remotePositionId=row.positionId,remotePositionName=row.positionName,
   remoteSupervisorId=row.supervisorId,remoteSupervisorName=row.supervisorName,employmentStatus=row.status,startDate=row.startDate,payType=row.payType,
   remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt
  )
 fun mergeInactive(current:Employee,row:RemoteInactiveEmployee,syncedAt:Long)=current.copy(isActive=false,employmentStatus="desvinculado",remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt)
}
