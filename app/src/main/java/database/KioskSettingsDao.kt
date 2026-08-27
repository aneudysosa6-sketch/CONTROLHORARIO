package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface KioskSettingsDao {
    @Query("SELECT * FROM kiosk_settings WHERE companyId = :companyId AND deviceId = :deviceId LIMIT 1")
    fun observe(companyId: String, deviceId: String): Flow<KioskSettingsEntity?>

    @Query("SELECT * FROM kiosk_settings WHERE companyId = :companyId AND deviceId = :deviceId LIMIT 1")
    suspend fun current(companyId: String, deviceId: String): KioskSettingsEntity?

    @Query("SELECT * FROM kiosk_settings WHERE deviceId = :deviceId ORDER BY lastSyncedAt DESC LIMIT 1")
    suspend fun currentForDevice(deviceId: String): KioskSettingsEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(settings: KioskSettingsEntity)
}
