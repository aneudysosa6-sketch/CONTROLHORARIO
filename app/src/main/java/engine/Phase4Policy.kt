package com.example.controlhorario.engine

import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.database.LoanEntity
import com.example.controlhorario.database.VacationEntity
import java.time.LocalDate

object LoanLifecyclePolicy {
    data class PaymentUpdate(val paidAmount: Double, val balance: Double, val status: String)

    fun canCreate(amount: Double) = amount.isFinite() && amount > 0.0

    fun canApprove(status: String, amount: Double, discount: Double) =
        status == LoanEntity.STATUS_PENDING && amount.isFinite() && discount.isFinite() &&
            amount > 0.0 && discount > 0.0 && discount <= amount

    fun canDeliver(status: String) = status == LoanEntity.STATUS_APPROVED
    fun canReject(status: String, reason: String) =
        status == LoanEntity.STATUS_PENDING && reason.isNotBlank()
    fun canCancel(status: String) = status == LoanEntity.STATUS_PENDING

    fun paymentUpdate(loan: LoanEntity, amount: Double): PaymentUpdate? {
        if (loan.status != LoanEntity.STATUS_DELIVERED || !amount.isFinite() ||
            amount <= 0.0 || amount > loan.balance) return null
        val balance = (loan.balance - amount).coerceAtLeast(0.0)
        return PaymentUpdate(
            paidAmount = loan.paidAmount + amount,
            balance = balance,
            status = if (balance == 0.0) LoanEntity.STATUS_PAID else LoanEntity.STATUS_DELIVERED
        )
    }
}

object VacationLifecyclePolicy {
    fun hasValidRange(startDate: String, endDate: String) = parseRange(startDate, endDate) != null
    fun canApprove(status: String, requested: Int, approved: Int, remaining: Int) =
        status == VacationEntity.STATUS_PENDING && requested > 0 &&
            approved in 1..requested && remaining >= 0
    fun canReject(status: String, reason: String) =
        status == VacationEntity.STATUS_PENDING && reason.isNotBlank()
    fun canCancel(status: String) = status == VacationEntity.STATUS_PENDING
}

object MedicalLicensePolicy {
    fun validateDirect(
        request: EmployeePermissionRequestEntity,
        startDate: String,
        endDate: String,
        payPercent: Double,
        monthlySalary: Double
    ): Boolean {
        if (request.requestType != EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE) return false
        if (request.status !in setOf(
                EmployeePermissionRequestEntity.STATUS_PENDING,
                EmployeePermissionRequestEntity.STATUS_ACTIVE
            )
        ) return false
        val range = parseRange(startDate, endDate) ?: return false
        if (request.status == EmployeePermissionRequestEntity.STATUS_ACTIVE &&
            request.licenseStartDate.isNotBlank() &&
            range.first.isBefore(LocalDate.parse(request.licenseStartDate))
        ) return false
        return payPercent.isFinite() && payPercent in 0.0..100.0 &&
            monthlySalary.isFinite() && monthlySalary >= 0.0
    }

    fun dates(startDate: String, endDate: String): List<String> {
        val (start, end) = parseRange(startDate, endDate) ?: return emptyList()
        return generateSequence(start) { it.plusDays(1).takeIf { next -> !next.isAfter(end) } }
            .map(LocalDate::toString).toList()
    }
}

private fun parseRange(startText: String, endText: String): Pair<LocalDate, LocalDate>? = try {
    val start = LocalDate.parse(startText)
    val end = LocalDate.parse(endText)
    if (end.isBefore(start)) null else start to end
} catch (_: Exception) {
    null
}