package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface DepartmentDao {
    @Query("SELECT * FROM departments ORDER BY active DESC, name")
    fun getAllDepartments(): Flow<List<DepartmentEntity>>

    @Query("SELECT * FROM departments WHERE branchId = :branchId ORDER BY active DESC, name")
    fun getDepartmentsByBranch(branchId: Int): Flow<List<DepartmentEntity>>

    @Insert
    suspend fun insert(department: DepartmentEntity)

    @Update
    suspend fun update(department: DepartmentEntity)
}