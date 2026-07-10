package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface SupervisorDao {

    @Query("SELECT * FROM supervisors ORDER BY fullName")
    fun getAllSupervisors(): Flow<List<SupervisorEntity>>

    @Query("SELECT * FROM supervisors WHERE id = :supervisorId LIMIT 1")
    suspend fun getSupervisorById(supervisorId: Int): SupervisorEntity?

    @Query("SELECT * FROM supervisors WHERE username = :username AND password = :password AND isActive = 1 LIMIT 1")
    suspend fun login(username: String, password: String): SupervisorEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun save(supervisor: SupervisorEntity): Long

    @Update
    suspend fun update(supervisor: SupervisorEntity)

    @Query("UPDATE supervisors SET isActive = :active, updatedAt = :updatedAt WHERE id = :supervisorId")
    suspend fun setActive(supervisorId: Int, active: Boolean, updatedAt: Long = System.currentTimeMillis())

    @Query("DELETE FROM supervisor_departments WHERE supervisorId = :supervisorId")
    suspend fun clearDepartments(supervisorId: Int)

    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun addDepartmentCrossRef(crossRef: SupervisorDepartmentEntity)

    @Query("SELECT departmentId FROM supervisor_departments WHERE supervisorId = :supervisorId")
    fun getDepartmentIdsForSupervisor(supervisorId: Int): Flow<List<Int>>

    @Query("SELECT departmentId FROM supervisor_departments WHERE supervisorId = :supervisorId")
    suspend fun getDepartmentIdsNow(supervisorId: Int): List<Int>
}
