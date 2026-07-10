package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.Query
import androidx.room.Update
import kotlinx.coroutines.flow.Flow

@Dao
interface BranchDao {

    @Query("SELECT * FROM branches ORDER BY name")
    fun getAllBranches(): Flow<List<BranchEntity>>

    @Insert
    suspend fun insert(branch: BranchEntity)

    @Update
    suspend fun update(branch: BranchEntity)

    @Delete
    suspend fun delete(branch: BranchEntity)
}