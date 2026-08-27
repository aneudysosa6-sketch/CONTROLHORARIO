package com.example.controlhorario.ui.payroll

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.CompanySettingsEntity
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.database.LaborCalendarDayEntity
import com.example.controlhorario.database.MedicalLicenseDailyPaymentEntity
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.GeneralPayrollExport

data class GeneralPayrollUiState(
    val snapshot: GeneralPayrollDataSnapshot? = null,
    val payroll: GeneralPayrollExport? = null,
    val message: String = "",
    val lastPdfPath: String = "",
    val lastCsvPath: String = "",
    val templateUploaded: Boolean = false,
    val templateHasErrors: Boolean = false
)

data class GeneralPayrollDataSnapshot(
    val employees: List<Employee>,
    val attendance: List<AttendanceEntity>,
    val laborDays: List<LaborCalendarDayEntity>,
    val payrollSettings: PayrollSettingsEntity?,
    val employeeSettings: List<EmployeePayrollSettingsEntity>,
    val medicalLicensePayments: List<MedicalLicenseDailyPaymentEntity>,
    val companySettings: CompanySettingsEntity?
)

data class PartialGeneralPayrollDataSnapshot(
    val employees: List<Employee>,
    val attendance: List<AttendanceEntity>,
    val laborDays: List<LaborCalendarDayEntity>,
    val payrollSettings: PayrollSettingsEntity?,
    val employeeSettings: List<EmployeePayrollSettingsEntity>,
    val medicalLicensePayments: List<MedicalLicenseDailyPaymentEntity>
)
