package com.example.controlhorario.engine

import com.example.controlhorario.database.EmployeePermissionRequestEntity
import com.example.controlhorario.database.LoanEntity
import com.example.controlhorario.database.VacationEntity
import org.junit.Assert.*
import org.junit.Test

class Phase4PolicyTest {
    @Test fun loanLifecycleRejectsInvalidTransitionsAndOverpayment() {
        assertTrue(LoanLifecyclePolicy.canApprove(LoanEntity.STATUS_PENDING, 1000.0, 100.0))
        assertFalse(LoanLifecyclePolicy.canApprove(LoanEntity.STATUS_APPROVED, 1000.0, 100.0))
        assertFalse(LoanLifecyclePolicy.canDeliver(LoanEntity.STATUS_PENDING))
        assertFalse(LoanLifecyclePolicy.canReject(LoanEntity.STATUS_PENDING, " "))
        val loan = LoanEntity(id = 1, employeeId = 2, balance = 200.0, paidAmount = 50.0, status = LoanEntity.STATUS_DELIVERED)
        assertNull(LoanLifecyclePolicy.paymentUpdate(loan, 201.0))
        val update = LoanLifecyclePolicy.paymentUpdate(loan, 200.0)
        assertNotNull(update)
        assertEquals(250.0, update!!.paidAmount, 0.001)
        assertEquals(LoanEntity.STATUS_PAID, update.status)
    }

    @Test fun vacationsRequireAValidRangeAndBoundedApproval() {
        assertTrue(VacationLifecyclePolicy.hasValidRange("2026-08-01", "2026-08-05"))
        assertFalse(VacationLifecyclePolicy.hasValidRange("2026-08-05", "2026-08-01"))
        assertTrue(VacationLifecyclePolicy.canApprove(VacationEntity.STATUS_PENDING, 5, 5, 10))
        assertFalse(VacationLifecyclePolicy.canApprove(VacationEntity.STATUS_PENDING, 5, 6, 9))
    }

    @Test fun medicalLicensesValidateDirectDatesPercentAndState() {
        val request = EmployeePermissionRequestEntity(id = 4, employeeId = 8, requestType = EmployeePermissionRequestEntity.TYPE_MEDICAL_LICENSE)
        assertTrue(MedicalLicensePolicy.validateDirect(request, "2026-08-01", "2026-08-03", 60.0, 100.0))
        assertFalse(MedicalLicensePolicy.validateDirect(request, "2026-08-03", "2026-08-01", 60.0, 100.0))
        assertFalse(MedicalLicensePolicy.validateDirect(request, "2026-08-01", "2026-08-03", 120.0, 100.0))
        assertEquals(listOf("2026-08-01", "2026-08-02", "2026-08-03"), MedicalLicensePolicy.dates("2026-08-01", "2026-08-03"))
    }
}