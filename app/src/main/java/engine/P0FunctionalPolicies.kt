package com.example.controlhorario.engine

import java.math.BigDecimal
import java.math.RoundingMode
import java.time.Duration
import java.time.Instant
import java.time.LocalDate

enum class TerminalUsageType { GENERAL, DEPARTMENTS }

data class TerminalConfiguration(
    val companyId: String,
    val branchId: String,
    val usageType: TerminalUsageType,
    val departmentIds: Set<String> = emptySet(),
)

data class TerminalEmployee(
    val companyId: String,
    val departmentId: String?,
    val active: Boolean,
)

object TerminalEligibilityPolicy {
    const val REJECTION_MESSAGE = "TERMINAL NO AUTORIZADO PARA SU DEPARTAMENTO"

    fun validate(configuration: TerminalConfiguration): Result<TerminalConfiguration> {
        if (configuration.companyId.isBlank() || configuration.branchId.isBlank()) {
            return Result.failure(IllegalArgumentException("Empresa y sucursal son obligatorias"))
        }
        if (configuration.usageType == TerminalUsageType.DEPARTMENTS && configuration.departmentIds.isEmpty()) {
            return Result.failure(IllegalArgumentException("Seleccione al menos un departamento"))
        }
        return Result.success(
            if (configuration.usageType == TerminalUsageType.GENERAL) {
                configuration.copy(departmentIds = emptySet())
            } else {
                configuration
            },
        )
    }

    fun isEligible(configuration: TerminalConfiguration, employee: TerminalEmployee): Boolean =
        employee.active && employee.companyId == configuration.companyId &&
            (configuration.usageType == TerminalUsageType.GENERAL ||
                employee.departmentId in configuration.departmentIds)
}

enum class LicenseStatus { ACTIVE, CANCELED }

data class DirectLicenseDay(
    val date: LocalDate,
    val percentage: BigDecimal,
    val amount: BigDecimal,
)

object DirectLicensePolicy {
    private val oneHundred = BigDecimal("100")
    private val thirty = BigDecimal("30")

    fun calculateDays(
        start: LocalDate,
        endInclusive: LocalDate,
        monthlySalary: BigDecimal,
        percentage: BigDecimal,
    ): List<DirectLicenseDay> {
        require(!endInclusive.isBefore(start)) { "La fecha final no puede ser anterior a la inicial" }
        require(monthlySalary >= BigDecimal.ZERO) { "El salario no puede ser negativo" }
        require(percentage >= BigDecimal.ZERO && percentage <= oneHundred) { "El porcentaje debe estar entre 0 y 100" }
        val dailyAmount = monthlySalary.divide(thirty, 8, RoundingMode.HALF_UP)
            .multiply(percentage)
            .divide(oneHundred, 2, RoundingMode.HALF_UP)
        return generateSequence(start) { current -> current.plusDays(1).takeUnless { it.isAfter(endInclusive) } }
            .map { DirectLicenseDay(it, percentage, dailyAmount) }
            .toList()
    }

    fun editableDates(originalStart: LocalDate, requestedStart: LocalDate, requestedEnd: LocalDate) {
        require(!requestedStart.isBefore(originalStart)) { "Solo se puede editar desde el inicio de la licencia hacia adelante" }
        require(!requestedEnd.isBefore(requestedStart)) { "Rango de licencia invalido" }
    }
}

enum class JourneyEventType { INICIAR, PAUSAR, REANUDAR, FINALIZAR }

data class JourneyEvent(val type: JourneyEventType, val occurredAt: Instant)

enum class IncompleteJourneyDecision { NO_PAY, PAY_DEMONSTRABLE }

data class NoPayResolution(
    val decision: IncompleteJourneyDecision,
    val recognizedMinutes: Int,
    val source: String,
)

object NoPayResolutionPolicy {
    fun resolve(
        events: List<JourneyEvent>,
        decision: IncompleteJourneyDecision,
        manualHours: BigDecimal? = null,
    ): NoPayResolution {
        require(events.isNotEmpty()) { "La jornada no contiene eventos" }
        if (decision == IncompleteJourneyDecision.NO_PAY) {
            require(manualHours == null) { "NO PAGAR no acepta horas manuales" }
            return NoPayResolution(decision, 0, "NO_PAY")
        }
        val ordered = events.sortedBy { it.occurredAt }
        val onlyStart = ordered.size == 1 && ordered.first().type == JourneyEventType.INICIAR
        if (onlyStart) {
            require(manualHours != null && manualHours >= BigDecimal.ZERO && manualHours <= BigDecimal("8")) {
                "Las horas manuales deben estar entre 0 y 8"
            }
            return NoPayResolution(
                decision,
                manualHours.multiply(BigDecimal("60")).setScale(0, RoundingMode.HALF_UP).toInt(),
                "MANUAL_ONLY_START",
            )
        }
        require(manualHours == null) { "Solo una jornada con INICIAR admite horas manuales" }
        var openedAt: Instant? = null
        var minutes = 0L
        for (event in ordered) {
            when (event.type) {
                JourneyEventType.INICIAR, JourneyEventType.REANUDAR -> if (openedAt == null) openedAt = event.occurredAt
                JourneyEventType.PAUSAR, JourneyEventType.FINALIZAR -> {
                    val start = openedAt
                    if (start != null && !event.occurredAt.isBefore(start)) {
                        minutes += Duration.between(start, event.occurredAt).toMinutes()
                        openedAt = null
                    }
                }
            }
        }
        return NoPayResolution(decision, minutes.coerceAtMost(Int.MAX_VALUE.toLong()).toInt(), "DEMONSTRABLE_INTERVALS")
    }

    fun requireOpenPayroll(isPayrollClosed: Boolean) {
        require(!isPayrollClosed) { "Una jornada solo es editable mientras la nomina esta abierta" }
    }
}

data class PriorAdjustment(
    val idempotencyKey: String,
    val sourcePayrollId: String,
    val employeeId: String,
    val amount: BigDecimal,
)

object PriorAdjustmentPolicy {
    fun delta(previous: BigDecimal, corrected: BigDecimal): BigDecimal = corrected.subtract(previous)

    fun appendIdempotently(existing: List<PriorAdjustment>, candidate: PriorAdjustment): List<PriorAdjustment> =
        if (existing.any { it.idempotencyKey == candidate.idempotencyKey }) existing else existing + candidate
}

data class MonthlyAttendanceCounters(
    val absences: Int,
    val lateArrivals: Int,
    val incompleteJourneys: Int,
)

enum class BlacklistReason { ABSENCES, LATE_ARRIVALS, INCOMPLETE_JOURNEYS }

object MonthlyBlacklistPolicy {
    fun reasons(counters: MonthlyAttendanceCounters): Set<BlacklistReason> = buildSet {
        if (counters.absences > 2) add(BlacklistReason.ABSENCES)
        if (counters.lateArrivals > 5) add(BlacklistReason.LATE_ARRIVALS)
        if (counters.incompleteJourneys > 5) add(BlacklistReason.INCOMPLETE_JOURNEYS)
    }

    fun blocksAttendance(@Suppress("UNUSED_PARAMETER") reasons: Set<BlacklistReason>): Boolean = false
}

data class OfflineEmployeeMessage(
    val id: String,
    val employeeId: String,
    val content: String,
    val deliveredAt: Instant? = null,
    val receiptConfirmed: Boolean = false,
)

object OfflineMessagePolicy {
    fun reconcile(local: List<OfflineEmployeeMessage>, remote: List<OfflineEmployeeMessage>): List<OfflineEmployeeMessage> {
        val remoteById = remote.associateBy { it.id }
        return remote.map { incoming -> local.firstOrNull { it.id == incoming.id } ?: incoming }
            .filterNot { it.receiptConfirmed || it.id !in remoteById }
    }

    fun deliverFirst(messages: List<OfflineEmployeeMessage>, employeeId: String, now: Instant): List<OfflineEmployeeMessage> {
        val first = messages.firstOrNull { it.employeeId == employeeId && it.deliveredAt == null && !it.receiptConfirmed } ?: return messages
        return messages.map { if (it.id == first.id) it.copy(deliveredAt = now) else it }
    }
}
