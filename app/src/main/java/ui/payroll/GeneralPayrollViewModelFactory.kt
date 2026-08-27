package com.example.controlhorario.ui.payroll

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import com.example.controlhorario.repository.AttendanceRepository
import com.example.controlhorario.repository.CompanySettingsRepository
import com.example.controlhorario.repository.EmployeePayrollSettingsRepository
import com.example.controlhorario.repository.EmployeePermissionRequestRepository
import com.example.controlhorario.repository.EmployeeRepository
import com.example.controlhorario.repository.LaborCalendarRepository
import com.example.controlhorario.repository.PayrollSettingsRepository

class GeneralPayrollViewModelFactory(
    private val employeeRepository: EmployeeRepository,
    private val attendanceRepository: AttendanceRepository,
    private val laborCalendarRepository: LaborCalendarRepository,
    private val payrollSettingsRepository: PayrollSettingsRepository,
    private val employeePayrollSettingsRepository: EmployeePayrollSettingsRepository,
    private val employeePermissionRequestRepository: EmployeePermissionRequestRepository,
    private val companySettingsRepository: CompanySettingsRepository
) : ViewModelProvider.Factory {
    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        return GeneralPayrollViewModel(
            employeeRepository = employeeRepository,
            attendanceRepository = attendanceRepository,
            laborCalendarRepository = laborCalendarRepository,
            payrollSettingsRepository = payrollSettingsRepository,
            employeePayrollSettingsRepository = employeePayrollSettingsRepository,
            employeePermissionRequestRepository = employeePermissionRequestRepository,
            companySettingsRepository = companySettingsRepository
        ) as T
    }
}
