package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query

@Dao interface EmployeeSyncOutboxDao{
 @Insert suspend fun insert(value:EmployeeSyncOutboxEntity):Long
 @Query("SELECT * FROM employee_sync_outbox WHERE status IN ('PENDING','FAILED') AND nextRetryAt<=:now ORDER BY id LIMIT :limit") suspend fun pending(now:Long,limit:Int=20):List<EmployeeSyncOutboxEntity>
 @Query("UPDATE employee_sync_outbox SET status='SYNCING',updatedAt=:now WHERE id=:id") suspend fun markSyncing(id:Long,now:Long)
 @Query("UPDATE employee_sync_outbox SET status='SYNCED',lastError=NULL,updatedAt=:now WHERE id=:id") suspend fun markSynced(id:Long,now:Long)
 @Query("UPDATE employee_sync_outbox SET status='FAILED',retryCount=retryCount+1,lastError=:error,nextRetryAt=:nextRetryAt,updatedAt=:now WHERE id=:id") suspend fun markFailed(id:Long,error:String,nextRetryAt:Long,now:Long)
}
