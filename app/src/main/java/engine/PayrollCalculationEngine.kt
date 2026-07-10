package com.example.controlhorario.engine

import com.example.controlhorario.database.AttendanceEntity
import com.example.controlhorario.database.EmployeePayrollSettingsEntity
import com.example.controlhorario.database.LaborCalendarDayEntity
import com.example.controlhorario.database.PayrollSettingsEntity
import com.example.controlhorario.model.Employee
import com.example.controlhorario.model.PayrollResult
import com.example.controlhorario.model.WorkScheduleTemplate
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.concurrent.TimeUnit

object PayrollCalculationEngine {

    fun calculateEmployeePayroll(
        employee: Employee,
        periodStart: String,
        periodEnd: String,
        attendanceRecords: List<AttendanceEntity>,
        laborCalendarDays: List<LaborCalendarDayEntity>,
        workScheduleTemplate: WorkScheduleTemplate?,
        generalSettings: PayrollSettingsEntity?,
        employeeSettings: EmployeePayrollSettingsEntity?
    ): PayrollResult {

        val employeeRecords = attendanceRecords
            .filter {
                it.employeeId == employee.id &&
                        it.date >= periodStart &&
                        it.date <= periodEnd
            }
            .sortedWith(
                compareBy<AttendanceEntity> { it.date }
                    .thenBy { it.time }
            )

        val recordsByDate = employeeRecords.groupBy { it.date }

        var totalWorkedHours = 0.0
        var sundayHours = 0.0
        var holidayHours = 0.0

        recordsByDate.forEach { (date, records) ->
            val dayWorkedHours = calculateWorkedHoursForDay(records)
            totalWorkedHours += dayWorkedHours

            if (isSunday(date)) {
                sundayHours += dayWorkedHours
            }

            if (isHoliday(date, laborCalendarDays)) {
                holidayHours += dayWorkedHours
            }
        }

        val maxNormalHours = workScheduleTemplate?.jornadaMaximaHoras ?: totalWorkedHours
        val normalHours = totalWorkedHours.coerceAtMost(maxNormalHours)
        val overtimeHours = (totalWorkedHours - maxNormalHours).coerceAtLeast(0.0)

        val nightHours = calculateNightHours(employeeRecords)

        val normalHourPrice = employeeSettings?.normalHourPrice
            ?: generalSettings?.normalHourPrice
            ?: 0.0

        val overtimeHourPrice = employeeSettings?.overtimeHourPrice
            ?: generalSettings?.overtimeHourPrice
            ?: 0.0

        val nightHourPrice = employeeSettings?.nightHourPrice
            ?: generalSettings?.nightHourPrice
            ?: 0.0

        val sundayHourPrice = employeeSettings?.sundayHourPrice
            ?: generalSettings?.sundayHourPrice
            ?: 0.0

        val holidayHourPrice = employeeSettings?.holidayHourPrice
            ?: generalSettings?.holidayHourPrice
            ?: 0.0

        val bonusAmount = employeeSettings?.bonusAmount
            ?: generalSettings?.bonusAmount
            ?: 0.0

        val commissionAmount = employeeSettings?.commissionAmount
            ?: generalSettings?.commissionAmount
            ?: 0.0

        val otherIncomeAmount = employeeSettings?.otherIncomeAmount
            ?: generalSettings?.otherIncomeAmount
            ?: 0.0

        val afpAmount = employeeSettings?.afpAmount
            ?: generalSettings?.afpAmount
            ?: 0.0

        val sfsAmount = employeeSettings?.sfsAmount
            ?: generalSettings?.sfsAmount
            ?: 0.0

        val isrAmount = employeeSettings?.isrAmount
            ?: generalSettings?.isrAmount
            ?: 0.0

        val loanAmount = employeeSettings?.loanAmount ?: 0.0
        val cooperativeAmount = employeeSettings?.cooperativeAmount ?: 0.0
        val privateInsuranceAmount = employeeSettings?.privateInsuranceAmount ?: 0.0
        val phoneDiscountAmount = employeeSettings?.phoneDiscountAmount ?: 0.0
        val foodDiscountAmount = employeeSettings?.foodDiscountAmount ?: 0.0
        val transportDiscountAmount = employeeSettings?.transportDiscountAmount ?: 0.0
        val oneTimeCreditAmount = employeeSettings?.oneTimeCreditAmount ?: 0.0
        val otherDiscountAmount = employeeSettings?.otherDiscountAmount
            ?: generalSettings?.otherDiscountAmount
            ?: 0.0

        val normalHourPayment = normalHours * normalHourPrice
        val overtimePayment = overtimeHours * overtimeHourPrice
        val nightPayment = nightHours * nightHourPrice
        val sundayPayment = sundayHours * sundayHourPrice
        val holidayPayment = holidayHours * holidayHourPrice

        val totalIncome =
            employee.sueldo +
                    normalHourPayment +
                    overtimePayment +
                    nightPayment +
                    sundayPayment +
                    holidayPayment +
                    bonusAmount +
                    commissionAmount +
                    otherIncomeAmount

        val totalDiscounts =
            afpAmount +
                    sfsAmount +
                    isrAmount +
                    loanAmount +
                    cooperativeAmount +
                    privateInsuranceAmount +
                    phoneDiscountAmount +
                    foodDiscountAmount +
                    transportDiscountAmount +
                    oneTimeCreditAmount +
                    otherDiscountAmount

        val netPay = totalIncome - totalDiscounts

        return PayrollResult(
            employeeId = employee.id,
            employeeName = employee.nombre,
            periodStart = periodStart,
            periodEnd = periodEnd,
            normalHours = normalHours,
            overtimeHours = overtimeHours,
            nightHours = nightHours,
            sundayHours = sundayHours,
            holidayHours = holidayHours,
            totalWorkedHours = totalWorkedHours,
            normalHourPayment = normalHourPayment,
            overtimePayment = overtimePayment,
            nightPayment = nightPayment,
            sundayPayment = sundayPayment,
            holidayPayment = holidayPayment,
            baseSalary = employee.sueldo,
            bonusAmount = bonusAmount,
            commissionAmount = commissionAmount,
            otherIncomeAmount = otherIncomeAmount,
            afpAmount = afpAmount,
            sfsAmount = sfsAmount,
            isrAmount = isrAmount,
            loanAmount = loanAmount,
            cooperativeAmount = cooperativeAmount,
            privateInsuranceAmount = privateInsuranceAmount,
            phoneDiscountAmount = phoneDiscountAmount,
            foodDiscountAmount = foodDiscountAmount,
            transportDiscountAmount = transportDiscountAmount,
            oneTimeCreditAmount = oneTimeCreditAmount,
            otherDiscountAmount = otherDiscountAmount,
            totalIncome = totalIncome,
            totalDiscounts = totalDiscounts,
            netPay = netPay,
            temporaryCreditMustBeCleared = oneTimeCreditAmount > 0.0,
            notes = if (oneTimeCreditAmount > 0.0) {
                "El crédito temporal debe limpiarse después de generar esta nómina."
            } else {
                ""
            }
        )
    }

    private fun calculateWorkedHoursForDay(
        records: List<AttendanceEntity>
    ): Double {
        val sortedRecords = records.sortedBy { it.time }

        val start = sortedRecords.firstOrNull {
            it.actionType == AttendanceAction.INICIO_JORNADA.name
        }

        val end = sortedRecords.lastOrNull {
            it.actionType == AttendanceAction.FIN_JORNADA.name
        }

        if (start == null || end == null) {
            return 0.0
        }

        val startMinutes = timeToMinutes(start.time)
        val endMinutes = timeToMinutes(end.time)

        if (endMinutes <= startMinutes) {
            return 0.0
        }

        var workedMinutes = endMinutes - startMinutes

        val pauses = sortedRecords.filter {
            it.actionType == AttendanceAction.PAUSA.name
        }

        pauses.forEach { pause ->
            val resume = sortedRecords.firstOrNull {
                it.actionType == AttendanceAction.REANUDAR.name &&
                        timeToMinutes(it.time) > timeToMinutes(pause.time)
            }

            if (resume != null) {
                workedMinutes -= timeToMinutes(resume.time) - timeToMinutes(pause.time)
            }
        }

        return minutesToHours(workedMinutes.coerceAtLeast(0))
    }

    private fun calculateNightHours(
        records: List<AttendanceEntity>
    ): Double {
        val recordsByDate = records.groupBy { it.date }
        var totalNightMinutes = 0

        recordsByDate.forEach { (_, dayRecords) ->
            val sortedRecords = dayRecords.sortedBy { it.time }

            val start = sortedRecords.firstOrNull {
                it.actionType == AttendanceAction.INICIO_JORNADA.name
            }

            val end = sortedRecords.lastOrNull {
                it.actionType == AttendanceAction.FIN_JORNADA.name
            }

            if (start != null && end != null) {
                val startMinutes = timeToMinutes(start.time)
                val endMinutes = timeToMinutes(end.time)

                for (minute in startMinutes until endMinutes) {
                    if (minute >= 21 * 60 || minute < 7 * 60) {
                        totalNightMinutes++
                    }
                }
            }
        }

        return minutesToHours(totalNightMinutes)
    }

    private fun isHoliday(
        date: String,
        laborCalendarDays: List<LaborCalendarDayEntity>
    ): Boolean {
        return laborCalendarDays.any {
            it.date == date && it.isPaid
        }
    }

    private fun isSunday(date: String): Boolean {
        return try {
            val formatter = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
            val parsedDate = formatter.parse(date) ?: return false
            val dayFormat = SimpleDateFormat("u", Locale.getDefault())
            dayFormat.format(parsedDate) == "7"
        } catch (e: Exception) {
            false
        }
    }

    private fun timeToMinutes(time: String): Int {
        return try {
            val parts = time.split(":")
            val hour = parts.getOrNull(0)?.toIntOrNull() ?: 0
            val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
            hour * 60 + minute
        } catch (e: Exception) {
            0
        }
    }

    private fun minutesToHours(minutes: Int): Double {
        val hours = TimeUnit.MINUTES.toMinutes(minutes.toLong()).toDouble() / 60.0
        return kotlin.math.round(hours * 100.0) / 100.0
    }
}