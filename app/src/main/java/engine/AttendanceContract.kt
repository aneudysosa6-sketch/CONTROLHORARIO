package com.example.controlhorario.engine

import java.time.Duration
import java.time.Instant

object AttendanceContract {
    const val VERSION = 1
    const val ERROR_INVALID_TRANSITION = "INVALID_TRANSITION"
    const val ERROR_ALREADY_FINALIZED = "ALREADY_FINALIZED"
}

enum class JourneyStatus { SIN_INICIAR, EN_CURSO, EN_PAUSA, FINALIZADA }
enum class JourneyAction { INICIAR, PAUSAR, REANUDAR, FINALIZAR }

data class JourneySnapshot(
    val status: JourneyStatus = JourneyStatus.SIN_INICIAR,
    val startedAt: String? = null,
    val pauseStartedAt: String? = null,
    val pauseEndedAt: String? = null,
    val finishedAt: String? = null,
    val workedMinutes: Int = 0,
    val breakMinutes: Int = 0
)

data class JourneyTransition(val accepted: Boolean, val snapshot: JourneySnapshot, val errorCode: String? = null)

object JourneyStateEngine {
    fun allowedActions(status: JourneyStatus): Set<JourneyAction> = when (status) {
        JourneyStatus.SIN_INICIAR -> setOf(JourneyAction.INICIAR)
        JourneyStatus.EN_CURSO -> setOf(JourneyAction.PAUSAR, JourneyAction.FINALIZAR)
        JourneyStatus.EN_PAUSA -> setOf(JourneyAction.REANUDAR, JourneyAction.FINALIZAR)
        JourneyStatus.FINALIZADA -> emptySet()
    }

    fun apply(current: JourneySnapshot, action: JourneyAction, occurredAt: String): JourneyTransition {
        if (current.status == JourneyStatus.FINALIZADA) return JourneyTransition(false, current, AttendanceContract.ERROR_ALREADY_FINALIZED)
        if (action !in allowedActions(current.status)) return JourneyTransition(false, current, AttendanceContract.ERROR_INVALID_TRANSITION)
        val next = when (action) {
            JourneyAction.INICIAR -> current.copy(status = JourneyStatus.EN_CURSO, startedAt = occurredAt)
            JourneyAction.PAUSAR -> current.copy(
                status = JourneyStatus.EN_PAUSA,
                pauseStartedAt = occurredAt,
                workedMinutes = current.workedMinutes + minutesBetween(current.pauseEndedAt ?: current.startedAt, occurredAt)
            )
            JourneyAction.REANUDAR -> current.copy(
                status = JourneyStatus.EN_CURSO,
                pauseEndedAt = occurredAt,
                breakMinutes = current.breakMinutes + minutesBetween(current.pauseStartedAt, occurredAt)
            )
            JourneyAction.FINALIZAR -> current.copy(
                status = JourneyStatus.FINALIZADA,
                finishedAt = occurredAt,
                workedMinutes = current.workedMinutes + if (current.status == JourneyStatus.EN_CURSO) minutesBetween(current.pauseEndedAt ?: current.startedAt, occurredAt) else 0,
                breakMinutes = current.breakMinutes + if (current.status == JourneyStatus.EN_PAUSA) minutesBetween(current.pauseStartedAt, occurredAt) else 0
            )
        }
        return JourneyTransition(true, next)
    }

    private fun minutesBetween(start: String?, end: String): Int = runCatching {
        if (start == null) 0 else Duration.between(Instant.parse(start), Instant.parse(end)).toMinutes().coerceAtLeast(0).toInt()
    }.getOrDefault(0)
}
