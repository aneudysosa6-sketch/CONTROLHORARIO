package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface MedicalLicenseDailyPaymentDao {
    @Query("SELECT * FROM medical_license_daily_payments WHERE isActive = 1 ORDER BY date DESC, id DESC")
    fun getAllPayments(): Flow<List<MedicalLicenseDailyPaymentEntity>>

    @Query("""
        SELECT * FROM medical_license_daily_payments
        WHERE isActive = 1 AND date >= :periodStart AND date <= :periodEnd
        ORDER BY date ASC
    """)
    fun getPaymentsByPeriod(periodStart: String, periodEnd: String): Flow<List<MedicalLicenseDailyPaymentEntity>>

    @Query("UPDATE medical_license_daily_payments SET isActive = 0 WHERE permissionRequestId = :requestId")
    suspend fun deactivateByRequest(requestId: Int)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun savePayments(payments: List<MedicalLicenseDailyPaymentEntity>)
}
