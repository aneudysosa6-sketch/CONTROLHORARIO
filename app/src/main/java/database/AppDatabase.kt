package com.example.controlhorario.database

import androidx.room.Database
import androidx.room.RoomDatabase
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.WorkScheduleTemplate

@Database(
    entities = [
        Employee::class,
        CompanySettingsEntity::class,
        WorkScheduleTemplate::class,
        LaborCalendarDayEntity::class,
        AttendanceEntity::class,
        JourneyEntity::class,
        JourneyOutboxEntity::class,
        JourneyConflictEntity::class,
        BranchEntity::class,
        DepartmentEntity::class,
        PayrollSettingsEntity::class,
        EmployeePayrollSettingsEntity::class,
        PayrollHistoryEntity::class,
        EmployeeDocumentEntity::class,
        LoanEntity::class,
        EmployeePermissionRequestEntity::class,
        MedicalLicenseDailyPaymentEntity::class,

        // ===== MÓDULO VACACIONES =====
        VacationEntity::class,
        EmployeeBiometricEntity::class,
        SupervisorPermissionEntity::class,

        // ===== MÓDULO USUARIOS =====
        AppUserEntity::class,

        // ===== MÓDULO SUPERVISORES =====
        SupervisorEntity::class,
        SupervisorDepartmentEntity::class,
        SupervisorWorkScheduleEntity::class,
        SupervisorEventEntity::class,
        PendingAttendanceReviewEntity::class,
        AppEventEntity::class
        ,DeviceEnrollmentEntity::class
    ],
    version = 30,
    exportSchema = false
)
abstract class AppDatabase : RoomDatabase() {

    abstract fun employeeDao(): EmployeeDao

    abstract fun companySettingsDao(): CompanySettingsDao

    abstract fun workScheduleTemplateDao(): WorkScheduleTemplateDao

    abstract fun laborCalendarDayDao(): LaborCalendarDayDao

    abstract fun attendanceDao(): AttendanceDao
    abstract fun journeyDao(): JourneyDao

    abstract fun branchDao(): BranchDao

    abstract fun departmentDao(): DepartmentDao

    abstract fun payrollSettingsDao(): PayrollSettingsDao

    abstract fun employeePayrollSettingsDao(): EmployeePayrollSettingsDao

    abstract fun payrollHistoryDao(): PayrollHistoryDao

    abstract fun employeeDocumentDao(): EmployeeDocumentDao

    abstract fun loanDao(): LoanDao

    abstract fun employeePermissionRequestDao(): EmployeePermissionRequestDao

    abstract fun medicalLicenseDailyPaymentDao(): MedicalLicenseDailyPaymentDao

    // ===== MÓDULO VACACIONES =====
    abstract fun vacationDao(): VacationDao

    abstract fun employeeBiometricDao(): EmployeeBiometricDao

    abstract fun supervisorPermissionDao(): SupervisorPermissionDao

    // ===== MÓDULO USUARIOS =====
    abstract fun appUserDao(): AppUserDao

    // ===== MÓDULO SUPERVISORES =====
    abstract fun supervisorDao(): SupervisorDao

    abstract fun supervisorWorkScheduleDao(): SupervisorWorkScheduleDao

    abstract fun supervisorEventDao(): SupervisorEventDao

    abstract fun pendingAttendanceReviewDao(): PendingAttendanceReviewDao

    abstract fun appEventDao(): AppEventDao
    abstract fun deviceEnrollmentDao():DeviceEnrollmentDao
}
