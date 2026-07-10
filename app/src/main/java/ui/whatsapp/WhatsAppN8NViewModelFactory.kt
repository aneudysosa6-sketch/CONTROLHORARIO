package com.example.controlhorario.ui.whatsapp

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.WhatsAppOutboxRepository

class WhatsAppN8NViewModelFactory(
    private val repository: WhatsAppOutboxRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        if (modelClass.isAssignableFrom(WhatsAppN8NViewModel::class.java)) {
            return WhatsAppN8NViewModel(repository) as T
        }
        throw IllegalArgumentException("Unknown ViewModel class: ${modelClass.name}")
    }
}
