package com.example.controlhorario.database
import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow
@Dao interface DeviceEnrollmentDao{
 @Insert(onConflict=OnConflictStrategy.REPLACE) suspend fun save(value:DeviceEnrollmentEntity)
 @Query("SELECT * FROM device_enrollment LIMIT 1") suspend fun current():DeviceEnrollmentEntity?
 @Query("SELECT * FROM device_enrollment LIMIT 1") fun observeCurrent():Flow<DeviceEnrollmentEntity?>
 @Query("UPDATE device_enrollment SET lastEmployeeSyncAt=:at WHERE deviceId=:deviceId") suspend fun markSynced(deviceId:String,at:Long)
 @Query("UPDATE device_enrollment SET lastEmployeeSyncAt=:at, employeeSyncCursorUpdatedAt=:cursorUpdatedAt, employeeSyncCursorId=:cursorId WHERE deviceId=:deviceId")
 suspend fun recordEmployeeSync(deviceId:String,at:Long,cursorUpdatedAt:String?,cursorId:String?)
}
