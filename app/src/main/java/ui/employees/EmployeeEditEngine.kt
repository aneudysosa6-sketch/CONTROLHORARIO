package com.example.controlhorario.ui.employees

import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.EmployeeCodePolicy

data class EmployeeEditableFields(
 val employeeCode:String,val nombre:String,val cedula:String,val telefono:String,val profilePhotoUri:String,
 val cargo:String,val departamento:String,val branchId:Int,val departmentId:Int,
 val sueldo:Double,val lunchHours:Double
)

object EmployeeEditEngine{
 fun routeKey(employee:Employee)=employee.remoteId?:employee.id.toString()
 fun fieldsFrom(employee:Employee)=EmployeeEditableFields(EmployeeCodePolicy.normalizeOrNull(employee.employeeCode).orEmpty(),employee.nombre,employee.cedula,employee.telefono,employee.profilePhotoUri,employee.cargo,employee.departamento,employee.branchId,employee.departmentId,employee.sueldo,employee.lunchHours)
 fun merge(existing:Employee,fields:EmployeeEditableFields,updatedAt:Long=System.currentTimeMillis()):Employee{
  val code=requireNotNull(EmployeeCodePolicy.normalizeOrNull(fields.employeeCode)){EmployeeCodePolicy.ERROR}
  return existing.copy(
  employeeCode=code,pin="",nombre=fields.nombre,cedula=fields.cedula,telefono=fields.telefono,profilePhotoUri=fields.profilePhotoUri,
  cargo=fields.cargo,departamento=fields.departamento,branchId=fields.branchId,departmentId=fields.departmentId,
  sueldo=fields.sueldo,lunchHours=fields.lunchHours,updatedAt=updatedAt
 )
 }
}
