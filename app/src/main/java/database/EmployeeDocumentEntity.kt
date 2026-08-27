package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "employee_documents")
data class EmployeeDocumentEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val employeeId: Int,
    val documentName: String,
    val documentType: String,
    val filePath: String,
    val fileExtension: String = "",
    val fileSizeBytes: Long = 0L,
    val uploadedAt: String,
    val notes: String = "",
    val isActive: Boolean = true
)