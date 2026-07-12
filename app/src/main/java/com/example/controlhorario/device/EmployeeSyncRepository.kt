package com.example.controlhorario.device
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.model.Employee

class EmployeeSyncRepository(private val database:AppDatabase){
 suspend fun replaceFromServer(rows:List<RemoteEmployee>){val dao=database.employeeDao();val now=System.currentTimeMillis();rows.forEach{row->
  val current=dao.findByRemoteId(row.id)?:dao.findAnyByEmployeeCode(row.code)
  val value=EmployeeSyncMapper.merge(current,row,now)
  if(current==null)dao.insertEmployee(value)else dao.updateEmployee(value)
 }}
}

object EmployeeSyncMapper{fun merge(current:Employee?,row:RemoteEmployee,syncedAt:Long):Employee=
 (current?:Employee(employeeCode=row.code,pin="")).copy(employeeCode=row.code,nombre=row.name,telefono=row.phone,isActive=row.active,remoteId=row.id,remoteBranchId=row.branchId,remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt)
}
