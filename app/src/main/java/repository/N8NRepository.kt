package com.example.controlhorario.repository

import com.example.controlhorario.database.N8NOutboxDao
import com.example.controlhorario.database.N8NOutboxEntity
import com.example.controlhorario.database.N8NSettingsDao
import com.example.controlhorario.database.N8NSettingsEntity
import com.example.controlhorario.database.N8NSyncLogDao
import com.example.controlhorario.database.N8NSyncLogEntity
import com.example.controlhorario.n8n.N8NHttpClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext

class N8NRepository(
    private val settingsDao: N8NSettingsDao,
    private val outboxDao: N8NOutboxDao,
    private val logDao: N8NSyncLogDao
) {
    fun observeSettings(): Flow<N8NSettingsEntity?> = settingsDao.observeSettings()
    fun observeOutbox(): Flow<List<N8NOutboxEntity>> = outboxDao.observeAll()
    fun observeLogs(): Flow<List<N8NSyncLogEntity>> = logDao.observeAll()

    suspend fun saveSettings(settings: N8NSettingsEntity) {
        settingsDao.save(settings.copy(id = 1, updatedAt = now()))
    }

    suspend fun resetSettings() {
        settingsDao.save(N8NSettingsEntity(updatedAt = now()))
    }

    suspend fun queueEvent(eventType: String, title: String, payloadJson: String) {
        val createdAt = now()
        outboxDao.save(
            N8NOutboxEntity(
                eventType = eventType,
                title = title,
                payloadJson = payloadJson,
                createdAt = createdAt,
                updatedAt = createdAt
            )
        )
    }

    suspend fun testConnection(settings: N8NSettingsEntity): N8NHttpClient.Result = withContext(Dispatchers.IO) {
        val testedAt = now()
        val payload = """
            {
              "type":"test_connection",
              "source":"osinet_android",
              "createdAt":"$testedAt"
            }
        """.trimIndent()
        val result = N8NHttpClient.post(settings.copy(enabled = true), payload)
        val status = if (result.success) N8NSettingsEntity.STATUS_CONNECTED else N8NSettingsEntity.STATUS_ERROR
        settingsDao.save(
            settings.copy(
                id = 1,
                lastStatus = status,
                lastMessage = result.message,
                lastTestAt = testedAt,
                updatedAt = testedAt
            )
        )
        logDao.save(
            N8NSyncLogEntity(
                eventType = "TEST_CONNECTION",
                status = status,
                requestSummary = "Prueba de conexión N8N",
                responseCode = result.code,
                responseMessage = result.body.take(250),
                errorMessage = if (result.success) "" else result.message,
                createdAt = testedAt
            )
        )
        result
    }

    suspend fun sendPending(): Int = withContext(Dispatchers.IO) {
        val settings = settingsDao.getSettings() ?: return@withContext 0
        if (!settings.enabled || settings.webhookUrl.isBlank()) return@withContext 0
        var sent = 0
        outboxDao.getByStatusOnce(N8NOutboxEntity.STATUS_PENDING).forEach { item ->
            val result = N8NHttpClient.post(settings, item.payloadJson)
            val at = now()
            if (result.success) {
                outboxDao.markSent(item.id, N8NOutboxEntity.STATUS_SENT, at, at, result.code, result.body.take(250))
                sent++
            } else {
                outboxDao.markError(item.id, N8NOutboxEntity.STATUS_ERROR, at, result.code, result.body.take(250), result.message)
            }
            logDao.save(
                N8NSyncLogEntity(
                    eventType = item.eventType,
                    status = if (result.success) N8NOutboxEntity.STATUS_SENT else N8NOutboxEntity.STATUS_ERROR,
                    requestSummary = item.title,
                    responseCode = result.code,
                    responseMessage = result.body.take(250),
                    errorMessage = if (result.success) "" else result.message,
                    createdAt = at
                )
            )
        }
        sent
    }

    suspend fun clearLogs() = logDao.clear()

    private fun now(): String = System.currentTimeMillis().toString()
}
