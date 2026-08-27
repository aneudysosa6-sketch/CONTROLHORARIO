package com.example.controlhorario.engine

import com.example.controlhorario.database.LoanEntity

object LoanEngine {
    data class Summary(
        val pending: Int,
        val approved: Int,
        val delivered: Int,
        val paid: Int,
        val activeBalance: Double
    )

    fun calculateSummary(loans: List<LoanEntity>): Summary =
        Summary(
            pending = loans.count { it.status == LoanEntity.STATUS_PENDING },
            approved = loans.count { it.status == LoanEntity.STATUS_APPROVED },
            delivered = loans.count { it.status == LoanEntity.STATUS_DELIVERED },
            paid = loans.count { it.status == LoanEntity.STATUS_PAID },
            activeBalance = loans
                .filter { it.status == LoanEntity.STATUS_DELIVERED || it.status == LoanEntity.STATUS_APPROVED }
                .sumOf { it.balance }
        )

    fun normalizeAmount(raw: String): Double =
        raw.replace(",", "").trim().toDoubleOrNull()?.coerceAtLeast(0.0) ?: 0.0
}
