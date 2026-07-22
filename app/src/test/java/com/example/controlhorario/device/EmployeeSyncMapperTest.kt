package com.example.controlhorario.device

import com.example.controlhorario.model.Employee
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class EmployeeSyncMapperTest{
 private val remote=RemoteEmployee(
  id="38c429cb-e9b4-48c7-82de-9ae8767cc6ef",code="000001",name="Ana OSINET",phone="8095550101",email="ana@osinet.test",
  branchId="056441ee-00a7-49c8-b0cb-12028ebcb44e",branchName="Principal",departmentId="156441ee-00a7-49c8-b0cb-12028ebcb44e",departmentName="Operaciones",
  positionId="256441ee-00a7-49c8-b0cb-12028ebcb44e",positionName="Analista",supervisorId="356441ee-00a7-49c8-b0cb-12028ebcb44e",supervisorName="Supervisora",
  status="activo",scheduleStart="08:00:00",scheduleEnd="17:00:00",lunchStart="12:00:00",lunchDurationMinutes=60,workDays="1,2,3,4,5",toleranceMinutes=15,startDate="2026-01-05",salary=45000.0,payType="quincenal",updatedAt="2026-07-12T10:00:00Z"
 )
 @Test fun `empleado nuevo recibe codigo canonico sin crear pin`(){val companyId="056441ee-00a7-49c8-b0cb-12028ebcb44e";val value=EmployeeSyncMapper.merge(null,remote,100,companyId);assertEquals(remote.id,value.remoteId);assertEquals(companyId,value.remoteCompanyId);assertEquals("000001",value.employeeCode);assertEquals("",value.pin);assertEquals("SYNCED",value.syncStatus);assertTrue(value.isActive);assertEquals(remote.email,value.email);assertEquals(remote.departmentId,value.remoteDepartmentId);assertEquals(remote.positionName,value.cargo);assertEquals(remote.supervisorName,value.remoteSupervisorName);assertEquals(remote.startDate,value.startDate);assertEquals(45000.0,value.sueldo,0.0);assertEquals(remote.payType,value.payType);assertEquals(100L,value.lastSyncedAt)}
 @Test fun `actualizacion normaliza codigo limpia pin obsoleto y conserva biometria`(){val local=Employee(id=7,employeeCode="00001",cedula="LOCAL",profilePhotoUri="content://foto",branchId=9,departmentId=4,pin="92841",fingerprintRegistered=true,fingerprintRegisteredAt="ayer",fingerprintRegisteredBy="admin");val value=EmployeeSyncMapper.merge(local,remote,200);assertEquals(7,value.id);assertEquals("000001",value.employeeCode);assertEquals("",value.pin);assertTrue(value.fingerprintRegistered);assertEquals("ayer",value.fingerprintRegisteredAt);assertEquals("LOCAL",value.cedula);assertEquals("content://foto",value.profilePhotoUri);assertEquals(9,value.branchId);assertEquals(4,value.departmentId);assertEquals(remote.branchId,value.remoteBranchId);assertEquals(remote.updatedAt,value.remoteUpdatedAt)}
 @Test fun `cambio remoto de codigo no vuelve a poblar pin`(){val local=Employee(id=7,employeeCode="000001",pin="000001");val value=EmployeeSyncMapper.merge(local,remote.copy(code="000002"),200);assertEquals("000002",value.employeeCode);assertEquals("",value.pin)}
 @Test fun `desactivacion tombstone limpia pin y conserva biometria y datos offline`(){val local=Employee(id=7,remoteId=remote.id,pin="92841",fingerprintRegistered=true,profilePhotoUri="content://foto");val value=EmployeeSyncMapper.mergeInactive(local,RemoteInactiveEmployee(remote.id,"2026-07-12T11:00:00Z"),300);assertFalse(value.isActive);assertEquals("desvinculado",value.employmentStatus);assertEquals("",value.pin);assertEquals("SYNCED",value.syncStatus);assertTrue(value.fingerprintRegistered);assertEquals("content://foto",value.profilePhotoUri);assertEquals(300L,value.lastSyncedAt)}
 @Test fun `empleado desactivado vuelve a activarse sin restaurar pin`(){val inactive=Employee(remoteId=remote.id,isActive=false,employmentStatus="desvinculado",pin="92841");val value=EmployeeSyncMapper.merge(inactive,remote,400);assertTrue(value.isActive);assertEquals("activo",value.employmentStatus);assertEquals("",value.pin)}
 @Test fun `horario operativo remoto se conserva para uso offline`(){val value=EmployeeSyncMapper.merge(null,remote,500);assertEquals("08:00:00",value.remoteScheduleStart);assertEquals("17:00:00",value.remoteScheduleEnd);assertEquals("12:00:00",value.remoteLunchStart);assertEquals(60,value.remoteLunchDurationMinutes);assertEquals("1,2,3,4,5",value.remoteWorkDays);assertEquals(15,value.remoteToleranceMinutes)}
 @Test fun `politica reintenta red y servidor pero no dispositivo revocado`(){assertEquals(EmployeeSyncFailureDecision.RETRY,EmployeeSyncRetryPolicy.decide(IOException("offline"),0));assertEquals(EmployeeSyncFailureDecision.RETRY,EmployeeSyncRetryPolicy.decide(DeviceEnrollmentHttpException(500,"","error"),0));assertEquals(EmployeeSyncFailureDecision.FAILURE,EmployeeSyncRetryPolicy.decide(DeviceEnrollmentHttpException(403,"","revocado"),0));assertFalse(EmployeeSyncRetryPolicy.decide(IllegalStateException(),3)==EmployeeSyncFailureDecision.RETRY)}
 @Test fun `consulta dirigida ignora cursor adelantado`(){val cursor=EmployeeSyncCursor("2099-01-01T00:00:00Z",remote.id);assertEquals(null,EmployeeSyncCursorPolicy.forRequest(cursor,"000001"));assertEquals(cursor,EmployeeSyncCursorPolicy.forRequest(cursor,null))}
}
