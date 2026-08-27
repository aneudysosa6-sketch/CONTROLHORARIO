package com.example.controlhorario.repository

import com.example.controlhorario.database.EmployeeDocumentDao
import com.example.controlhorario.database.EmployeeDocumentEntity
import kotlinx.coroutines.flow.Flow

class EmployeeDocumentRepository(
    private val dao: EmployeeDocumentDao
) {
    fun getDocumentsByEmployee(employeeId: Int): Flow<List<EmployeeDocumentEntity>> {
        return dao.getDocumentsByEmployee(employeeId)
    }

    suspend fun saveDocument(document: EmployeeDocumentEntity) {
        dao.saveDocument(document)
    }

    suspend fun deactivateDocument(documentId: Int) {
        dao.deactivateDocument(documentId)
    }
}