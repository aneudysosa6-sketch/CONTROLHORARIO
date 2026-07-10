package com.example.controlhorario.ui.whatsapp

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.repository.WhatsAppOutboxRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class WhatsAppN8NViewModel(
    private val repository: WhatsAppOutboxRepository
) : ViewModel() {
    val messages = repository.getAll().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun queueMessage(phone: String, message: String) {
        viewModelScope.launch {
            repository.save(
                com.example.controlhorario.database.WhatsAppOutboxEntity(
                    phoneNumber = phone,
                    message = message,
                    createdAt = System.currentTimeMillis().toString()
                )
            )
        }
    }
}
