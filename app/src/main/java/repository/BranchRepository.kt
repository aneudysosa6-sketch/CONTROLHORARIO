package com.example.controlhorario.repository

import com.example.controlhorario.database.BranchDao
import com.example.controlhorario.database.BranchEntity
import kotlinx.coroutines.flow.Flow

class BranchRepository(
    private val dao: BranchDao
) {

    fun getAllBranches(): Flow<List<BranchEntity>> {
        return dao.getAllBranches()
    }

    suspend fun insert(branch: BranchEntity) {
        dao.insert(branch)
    }

    suspend fun update(branch: BranchEntity) {
        dao.update(branch)
    }

    suspend fun delete(branch: BranchEntity) {
        dao.delete(branch)
    }
}