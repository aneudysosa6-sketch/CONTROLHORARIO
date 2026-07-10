package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface PendingAttendanceReviewDao {

    @Query("SELECT * FROM pending_attendance_reviews ORDER BY createdAt DESC")
    fun getAll(): Flow<List<PendingAttendanceReviewEntity>>

    @Query("SELECT * FROM pending_attendance_reviews WHERE status = :status ORDER BY createdAt DESC")
    fun getByStatus(status: String = PendingAttendanceReviewEntity.STATUS_PENDING): Flow<List<PendingAttendanceReviewEntity>>

    @Query("SELECT * FROM pending_attendance_reviews WHERE employeeId = :employeeId AND reviewDate = :reviewDate AND status = :status LIMIT 1")
    suspend fun findPendingForEmployeeDate(
        employeeId: Int,
        reviewDate: String,
        status: String = PendingAttendanceReviewEntity.STATUS_PENDING
    ): PendingAttendanceReviewEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(entity: PendingAttendanceReviewEntity): Long

    @Update
    suspend fun update(entity: PendingAttendanceReviewEntity)

    @Query("UPDATE pending_attendance_reviews SET status = :status, adminNote = :note, reviewedBy = :reviewedBy, reviewedAt = :reviewedAt, updatedAt = :updatedAt WHERE id = :id")
    suspend fun updateStatus(
        id: Int,
        status: String,
        note: String,
        reviewedBy: String,
        reviewedAt: Long = System.currentTimeMillis(),
        updatedAt: Long = System.currentTimeMillis()
    )
}
