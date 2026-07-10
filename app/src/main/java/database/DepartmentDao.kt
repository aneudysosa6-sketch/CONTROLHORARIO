package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface DepartmentDao {

    @Query("SELECT * FROM departments ORDER BY name")
    fun getAllDepartments(): Flow<List<DepartmentEntity>>

    @Query("SELECT * FROM departments WHERE branchId = :branchId ORDER BY name")
    fun getDepartmentsByBranch(branchId: Int): Flow<List<DepartmentEntity>>

    @Insert
    suspend fun insert(department: DepartmentEntity)

    @Update
    suspend fun update(department: DepartmentEntity)

    @Delete
    suspend fun delete(department: DepartmentEntity)
}