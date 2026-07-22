package com.example.controlhorario.device

import androidx.room.withTransaction
import android.util.Log
import com.example.controlhorario.database.AppDatabase
import com.example.controlhorario.database.EmployeeFaceBiometricEntity
import com.example.controlhorario.database.KioskSettingsEntity
import com.example.controlhorario.face.FaceEmbeddingCipher
import com.example.controlhorario.model.Employee
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

data class EmployeeSyncSummary(
 val downloaded:Int,val activated:Int,val deactivated:Int,val syncedAt:Long,
 val targetedEmployeeFound:Boolean?=null,val targetedEmployeeActive:Boolean?=null,
 val targetedRemoteEmbeddingPresent:Boolean?=null,val targetedRemoteEmbeddingDimension:Int?=null,
 val targetedRemoteEmbeddingValid:Boolean?=null
)

class EmployeeSyncRepository(private val database:AppDatabase){
 suspend fun sync(client:EmployeeSyncClient,deviceId:String,credential:String):EmployeeSyncSummary=
  SYNC_MUTEX.withLock{syncLocked(client,deviceId,credential,null)}

 suspend fun syncEmployeeFace(client:EmployeeSyncClient,deviceId:String,credential:String,employeeCode:String):EmployeeSyncSummary{
  require(employeeCode.matches(Regex("^[0-9]{5,12}$")))
  return SYNC_MUTEX.withLock{syncLocked(client,deviceId,credential,employeeCode)}
 }

 private suspend fun syncLocked(client:EmployeeSyncClient,deviceId:String,credential:String,employeeCode:String?):EmployeeSyncSummary{
  val enrollment=database.deviceEnrollmentDao().current()
  var cursor=EmployeeSyncCursorPolicy.forRequest(enrollment?.employeeSyncCursorUpdatedAt?.let{EmployeeSyncCursor(it,enrollment.employeeSyncCursorId.orEmpty())},employeeCode)
  var downloaded=0;var activated=0;var deactivated=0;var inserted=0;var updated=0;var discarded=0
  var targetedEmployeeFound:Boolean?=null;var targetedEmployeeActive:Boolean?=null
  var targetedEmbeddingPresent:Boolean?=null;var targetedEmbeddingDimension:Int?=null;var targetedEmbeddingValid:Boolean?=null
  Log.d(TAG,"Room sync inicio: device_id=$deviceId, cursor=$cursor, last_sync=${enrollment?.lastEmployeeSyncAt}")
  if(employeeCode!=null)Log.d(FACE_TAG,"employeeCode=$employeeCode targetedSyncStarted=true")
  do{
   val page=client.download(deviceId,credential,cursor,employeeCode);val syncedAt=System.currentTimeMillis()
   if(employeeCode!=null){
    val activeRow=page.employees.firstOrNull();val inactiveRow=page.inactive.firstOrNull()
    targetedEmployeeFound=activeRow!=null||inactiveRow!=null;targetedEmployeeActive=activeRow!=null
    targetedEmbeddingPresent=activeRow?.remoteEmbeddingPresent
    targetedEmbeddingDimension=activeRow?.remoteEmbeddingDimension
    targetedEmbeddingValid=activeRow?.remoteEmbeddingValid
   }
   val remoteCompanyId=page.companyId?:enrollment?.companyId?:error("employee_sync_company_scope_missing")
   Log.d(TAG,"Room recibe página: activos=${page.employees.size}, inactivos=${page.inactive.size}, cursor_respuesta=${page.cursor}")
   database.withTransaction{
    page.companySettings?.let{settings->
     database.kioskSettingsDao().save(KioskSettingsEntity(
      companyId=settings.companyId,deviceId=deviceId,faceOnlyEnabled=settings.faceOnlyEnabled,
      pinFallbackEnabled=settings.pinFallbackEnabled,faceMatchThreshold=settings.faceMatchThreshold,
      faceMatchMargin=settings.faceMatchMargin,remoteUpdatedAt=settings.updatedAt,lastSyncedAt=syncedAt
     ))
     Log.d(KIOSK_TAG,"companyId=${settings.companyId} deviceId=$deviceId pinFallbackEnabled=${settings.pinFallbackEnabled} faceOnlyEnabled=${settings.faceOnlyEnabled} settingsSynced=true")
    }
    val dao=database.employeeDao()
    val scopedEmployees=dao.backfillRemoteCompanyScope(remoteCompanyId)
    if(scopedEmployees>0)Log.d(KIOSK_TAG,"companyId=$remoteCompanyId employeeScopeBackfilled=$scopedEmployees")
    page.employees.forEach{row->
     val remoteMatch=dao.findByRemoteId(row.id);val codeMatch=if(remoteMatch==null)dao.findAnyByEmployeeCode(row.code)else null;val current=remoteMatch?:codeMatch
     if(current?.remoteCompanyId!=null&&current.remoteCompanyId!=remoteCompanyId){
      database.employeeFaceBiometricDao().deleteForEmployee(current.id)
      Log.w(TAG,"plantilla local aislada por cambio de empresa: local_id=${current.id}, remote_id=${row.id}")
     }
     var localId=current?.id
     if(current?.remoteUpdatedAt==null||current.remoteUpdatedAt<=row.updatedAt){
      val value=EmployeeSyncMapper.merge(current,row,syncedAt,remoteCompanyId)
      localId=if(current==null){dao.insertEmployee(value).toInt().also{inserted++;Log.d(TAG,"insertado remote_id=${row.id}, code=${row.code}")}}else{dao.updateEmployee(value);updated++;current.id}
      if(current?.isActive!=true)activated++
     }else{discarded++;Log.w(TAG,"descartado remote_id=${row.id}: updated_at remoto ${row.updatedAt} no supera local ${current.remoteUpdatedAt}")}
     val resolvedLocalId=localId ?: error("local_employee_id_unresolved")
     val localFaceBefore=database.employeeFaceBiometricDao().activeForEmployee(resolvedLocalId)!=null
     if(FacePersistencePolicy.shouldStore(row.faceEmbedding,localFaceBefore)){
      val embedding=requireNotNull(row.faceEmbedding)
      database.employeeFaceBiometricDao().replaceForEmployee(EmployeeFaceBiometricEntity(employeeId=resolvedLocalId,encryptedEmbedding=FaceEmbeddingCipher().encrypt(embedding),embeddingVersion=1,modelName="FaceNet-128",embeddingDimension=128,registeredAt=row.updatedAt,registeredBy="SUPABASE",updatedAt=row.updatedAt))
     }
     val localFaceAfter=database.employeeFaceBiometricDao().activeForEmployee(resolvedLocalId)!=null
     Log.d(FACE_TAG,"employeeCode=${row.code} remoteId=${row.id} localEmployeeId=$resolvedLocalId localFaceBefore=$localFaceBefore remoteEmbeddingPresent=${row.remoteEmbeddingPresent} remoteEmbeddingDimension=${row.remoteEmbeddingDimension} localFaceAfter=$localFaceAfter finalResult=${if(localFaceAfter)"LOCAL_FACE_AVAILABLE" else "REMOTE_FACE_MISSING"}")
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
   page.companyId?.let{database.deviceEnrollmentDao().recordScope(deviceId,it,page.deviceBranchId)}
   if(employeeCode==null)cursor=page.cursor
  }while(employeeCode==null&&page.hasMore)
  val completedAt=System.currentTimeMillis()
  if(employeeCode==null)database.deviceEnrollmentDao().recordEmployeeSync(deviceId,completedAt,cursor?.updatedAt,cursor?.id)
  Log.d(TAG,"Room sync final: recibidos=$downloaded, insertados=$inserted, actualizados=$updated, descartados=$discarded, activados=$activated, desactivados=$deactivated, cursor_guardado=$cursor")
  return EmployeeSyncSummary(downloaded,activated,deactivated,completedAt,targetedEmployeeFound,targetedEmployeeActive,targetedEmbeddingPresent,targetedEmbeddingDimension,targetedEmbeddingValid)
 }
 private companion object{const val TAG="EmployeeSync";const val FACE_TAG="FACE_CROSS_DEVICE_SYNC";const val KIOSK_TAG="KIOSK_SETTINGS_SYNC";val SYNC_MUTEX=Mutex()}
}

object FacePersistencePolicy{
 fun shouldStore(remoteEmbedding:FloatArray?,localFaceExists:Boolean):Boolean=
  !localFaceExists&&remoteEmbedding?.let{it.size==128&&it.all(Float::isFinite)}==true
}

object EmployeeSyncCursorPolicy{
 fun forRequest(cursor:EmployeeSyncCursor?,employeeCode:String?):EmployeeSyncCursor?=if(employeeCode==null)cursor else null
}

object EmployeeSyncMapper{
 fun merge(current:Employee?,row:RemoteEmployee,syncedAt:Long,remoteCompanyId:String?=current?.remoteCompanyId):Employee=
  (current?:Employee(employeeCode=row.code,pin="")).copy(
   employeeCode=row.code,nombre=row.name,telefono=row.phone,email=row.email,cargo=row.positionName,departamento=row.departmentName,
   sueldo=row.salary?:0.0,isActive=true,remoteId=row.id,remoteCompanyId=remoteCompanyId,remoteBranchId=row.branchId,remoteBranchName=row.branchName,
   remoteDepartmentId=row.departmentId,remoteDepartmentName=row.departmentName,remotePositionId=row.positionId,remotePositionName=row.positionName,
   remoteSupervisorId=row.supervisorId,remoteSupervisorName=row.supervisorName,employmentStatus=row.status,jornadaEnabled=row.jornadaEnabled,
   remoteScheduleStart=row.scheduleStart,remoteScheduleEnd=row.scheduleEnd,remoteLunchStart=row.lunchStart,remoteLunchDurationMinutes=row.lunchDurationMinutes,
   remoteWorkDays=row.workDays,remoteToleranceMinutes=row.toleranceMinutes,startDate=row.startDate,payType=row.payType,
   remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt
  )
 fun mergeInactive(current:Employee,row:RemoteInactiveEmployee,syncedAt:Long)=current.copy(isActive=false,employmentStatus="desvinculado",remoteUpdatedAt=row.updatedAt,lastSyncedAt=syncedAt)
}
