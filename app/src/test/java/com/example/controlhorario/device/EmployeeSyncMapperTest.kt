package com.example.controlhorario.device
import com.example.controlhorario.model.Employee
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeSyncMapperTest{
 private val remote=RemoteEmployee("38c429cb-e9b4-48c7-82de-9ae8767cc6ef","00001","Ana OSINET","8095550101",false,"056441ee-00a7-49c8-b0cb-12028ebcb44e","2026-07-12T10:00:00Z")
 @Test fun `empleado nuevo recibe uuid remoto sin inventar pin`(){val value=EmployeeSyncMapper.merge(null,remote,100);assertEquals(remote.id,value.remoteId);assertEquals("",value.pin);assertFalse(value.isActive);assertEquals(100L,value.lastSyncedAt)}
 @Test fun `actualizacion preserva pin y biometria locales`(){val local=Employee(id=7,employeeCode="00001",pin="92841",fingerprintRegistered=true);val value=EmployeeSyncMapper.merge(local,remote,200);assertEquals(7,value.id);assertEquals("92841",value.pin);assertTrue(value.fingerprintRegistered);assertEquals(remote.branchId,value.remoteBranchId)}
}
