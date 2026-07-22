package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao interface EmployeeSyncOutboxDao{
 @Insert suspend fun insert(value:EmployeeSyncOutboxEntity):Long
 @Query("SELECT * FROM employee_sync_outbox WHERE status IN ('PENDING','FAILED') AND nextRetryAt<=:now ORDER BY id LIMIT :limit") suspend fun pending(now:Long,limit:Int=20):List<EmployeeSyncOutboxEntity>
 @Query("SELECT COUNT(*) FROM employee_sync_outbox WHERE employeeLocalId=:employeeId AND operation='CREATE' AND status<>'SYNCED'") suspend fun hasPendingCreate(employeeId:Int):Int
 @Query("SELECT * FROM employee_sync_outbox WHERE employeeLocalId=:employeeId AND status<>'SYNCED' ORDER BY id") suspend fun unsyncedForEmployee(employeeId:Int):List<EmployeeSyncOutboxEntity>
 @Query("UPDATE employee_sync_outbox SET payloadJson=:payloadJson,updatedAt=:now WHERE id=:id") suspend fun updatePayload(id:Long,payloadJson:String,now:Long)
 @Query("UPDATE employee_sync_outbox SET status='FAILED',retryCount=retryCount+1,lastError='EMPLOYEE_UPLOAD_INTERRUPTED',nextRetryAt=:now,updatedAt=:now WHERE status='SYNCING'")
 suspend fun recoverInterruptedSyncing(now:Long):Int
 @Query("UPDATE employee_sync_outbox SET status='SYNCING',updatedAt=:now WHERE id=:id") suspend fun markSyncing(id:Long,now:Long)
 @Query("UPDATE employee_sync_outbox SET status='SYNCED',lastError=NULL,updatedAt=:now WHERE id=:id") suspend fun markSynced(id:Long,now:Long)
 @Query("UPDATE employee_sync_outbox SET status='FAILED',retryCount=retryCount+1,lastError=:error,nextRetryAt=:nextRetryAt,updatedAt=:now WHERE id=:id") suspend fun markFailed(id:Long,error:String,nextRetryAt:Long,now:Long)
}
