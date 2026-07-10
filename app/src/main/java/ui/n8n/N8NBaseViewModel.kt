package com.example.controlhorario.ui.n8n

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.N8NSettingsEntity
import com.example.controlhorario.repository.N8NRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class N8NBaseViewModel(
    private val repository: N8NRepository
) : ViewModel() {
    val settings = repository.observeSettings().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), null)
    val outbox = repository.observeOutbox().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())
    val logs = repository.observeLogs().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    fun saveSettings(
        webhookUrl: String,
        apiKey: String,
        bearerToken: String,
        timeoutSeconds: Int,
        enabled: Boolean
    ) {
        viewModelScope.launch {
            val current = settings.value ?: N8NSettingsEntity()
            repository.saveSettings(
                current.copy(
                    webhookUrl = webhookUrl.trim(),
                    apiKey = apiKey.trim(),
                    bearerToken = bearerToken.trim(),
                    timeoutSeconds = timeoutSeconds.coerceAtLeast(5),
                    enabled = enabled
                )
            )
        }
    }

    fun resetSettings() {
        viewModelScope.launch { repository.resetSettings() }
    }

    fun testConnection(
        webhookUrl: String,
        apiKey: String,
        bearerToken: String,
        timeoutSeconds: Int,
        enabled: Boolean
    ) {
        viewModelScope.launch {
            val base = (settings.value ?: N8NSettingsEntity()).copy(
                webhookUrl = webhookUrl.trim(),
                apiKey = apiKey.trim(),
                bearerToken = bearerToken.trim(),
                timeoutSeconds = timeoutSeconds.coerceAtLeast(5),
                enabled = enabled
            )
            repository.testConnection(base)
        }
    }

    fun queueTestEvent() {
        viewModelScope.launch {
            val at = System.currentTimeMillis().toString()
            repository.queueEvent(
                eventType = "MANUAL_TEST_EVENT",
                title = "Evento manual de prueba",
                payloadJson = """
                    {
                      "type":"manual_test_event",
                      "source":"osinet_android",
                      "createdAt":"$at"
                    }
                """.trimIndent()
            )
        }
    }

    fun sendPending() {
        viewModelScope.launch { repository.sendPending() }
    }

    fun clearLogs() {
        viewModelScope.launch { repository.clearLogs() }
    }
}
