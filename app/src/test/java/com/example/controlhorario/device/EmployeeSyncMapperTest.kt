package com.example.controlhorario.device

import com.example.controlhorario.model.Employee
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.IOException

class EmployeeSyncMapperTest{
 private val remote=RemoteEmployee(
  id="38c429cb-e9b4-48c7-82de-9ae8767cc6ef",code="00001",name="Ana OSINET",phone="8095550101",email="ana@osinet.test",
  branchId="056441ee-00a7-49c8-b0cb-12028ebcb44e",branchName="Principal",departmentId="156441ee-00a7-49c8-b0cb-12028ebcb44e",departmentName="Operaciones",
  positionId="256441ee-00a7-49c8-b0cb-12028ebcb44e",positionName="Analista",supervisorId="356441ee-00a7-49c8-b0cb-12028ebcb44e",supervisorName="Supervisora",
  status="activo",startDate="2026-01-05",salary=45000.0,payType="quincenal",updatedAt="2026-07-12T10:00:00Z"
 )
 @Test fun `empleado nuevo recibe uuid remoto y todos los campos sin inventar pin`(){val value=EmployeeSyncMapper.merge(null,remote,100);assertEquals(remote.id,value.remoteId);assertEquals("",value.pin);assertTrue(value.isActive);assertEquals(remote.email,value.email);assertEquals(remote.departmentId,value.remoteDepartmentId);assertEquals(remote.positionName,value.cargo);assertEquals(remote.supervisorName,value.remoteSupervisorName);assertEquals(remote.startDate,value.startDate);assertEquals(45000.0,value.sueldo,0.0);assertEquals(remote.payType,value.payType);assertEquals(100L,value.lastSyncedAt)}
 @Test fun `actualizacion conserva datos locales offline pin y biometria`(){val local=Employee(id=7,employeeCode="00001",cedula="LOCAL",profilePhotoUri="content://foto",branchId=9,departmentId=4,pin="92841",fingerprintRegistered=true,fingerprintRegisteredAt="ayer",fingerprintRegisteredBy="admin");val value=EmployeeSyncMapper.merge(local,remote,200);assertEquals(7,value.id);assertEquals("92841",value.pin);assertTrue(value.fingerprintRegistered);assertEquals("ayer",value.fingerprintRegisteredAt);assertEquals("LOCAL",value.cedula);assertEquals("content://foto",value.profilePhotoUri);assertEquals(9,value.branchId);assertEquals(4,value.departmentId);assertEquals(remote.branchId,value.remoteBranchId);assertEquals(remote.updatedAt,value.remoteUpdatedAt)}
 @Test fun `desactivacion tombstone conserva pin biometria y datos offline`(){val local=Employee(id=7,remoteId=remote.id,pin="92841",fingerprintRegistered=true,profilePhotoUri="content://foto");val value=EmployeeSyncMapper.mergeInactive(local,RemoteInactiveEmployee(remote.id,"2026-07-12T11:00:00Z"),300);assertFalse(value.isActive);assertEquals("desvinculado",value.employmentStatus);assertEquals("92841",value.pin);assertTrue(value.fingerprintRegistered);assertEquals("content://foto",value.profilePhotoUri);assertEquals(300L,value.lastSyncedAt)}
 @Test fun `empleado desactivado vuelve a activarse con una fila remota activa`(){val inactive=Employee(remoteId=remote.id,isActive=false,employmentStatus="desvinculado",pin="92841");val value=EmployeeSyncMapper.merge(inactive,remote,400);assertTrue(value.isActive);assertEquals("activo",value.employmentStatus);assertEquals("92841",value.pin)}
 @Test fun `politica reintenta red y servidor pero no dispositivo revocado`(){assertEquals(EmployeeSyncFailureDecision.RETRY,EmployeeSyncRetryPolicy.decide(IOException("offline"),0));assertEquals(EmployeeSyncFailureDecision.RETRY,EmployeeSyncRetryPolicy.decide(DeviceEnrollmentHttpException(500,"","error"),0));assertEquals(EmployeeSyncFailureDecision.FAILURE,EmployeeSyncRetryPolicy.decide(DeviceEnrollmentHttpException(403,"","revocado"),0));assertFalse(EmployeeSyncRetryPolicy.decide(IllegalStateException(),3)==EmployeeSyncFailureDecision.RETRY)}
}
