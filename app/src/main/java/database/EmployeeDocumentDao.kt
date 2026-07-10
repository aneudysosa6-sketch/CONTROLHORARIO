package com.example.controlhorario.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface EmployeeDocumentDao {

    @Query("SELECT * FROM employee_documents WHERE employeeId = :employeeId AND isActive = 1 ORDER BY id DESC")
    fun getDocumentsByEmployee(employeeId: Int): Flow<List<EmployeeDocumentEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun saveDocument(document: EmployeeDocumentEntity)

    @Query("UPDATE employee_documents SET isActive = 0 WHERE id = :documentId")
    suspend fun deactivateDocument(documentId: Int)
}