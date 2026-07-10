package com.example.controlhorario.ui.employees

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.EmployeeDocumentEntity
import com.example.controlhorario.repository.EmployeeDocumentRepository
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class EmployeeDocumentsViewModel(
    private val repository: EmployeeDocumentRepository
) : ViewModel() {

    private val _documents = MutableStateFlow<List<EmployeeDocumentEntity>>(emptyList())
    val documents: StateFlow<List<EmployeeDocumentEntity>> = _documents

    private val _message = MutableStateFlow("")
    val message: StateFlow<String> = _message

    fun loadDocuments(employeeId: Int) {
        viewModelScope.launch {
            repository.getDocumentsByEmployee(employeeId).collect { result ->
                _documents.value = result
            }
        }
    }

    fun saveDocument(document: EmployeeDocumentEntity) {
        viewModelScope.launch {
            repository.saveDocument(document)
        }
    }

    fun deactivateDocument(documentId: Int) {
        viewModelScope.launch {
            repository.deactivateDocument(documentId)
            _message.value = "Documento eliminado del expediente."
        }
    }

    fun markDocumentAction(documentId: Int, message: String) {
        _message.value = "$message. ID: $documentId"
    }
}