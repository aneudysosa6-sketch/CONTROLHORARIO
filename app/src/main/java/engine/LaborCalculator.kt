package com.example.controlhorario.engine

object LaborCalculator {

    fun calculate(workDay: LaborWorkDay): LaborCalculationResult {

        val workedMinutes = TimeCalculator.calculateWorkedMinutes(
            start = workDay.realStart,
            end = workDay.realEnd,
            breakMinutes = workDay.breakMinutes
        )

        val scheduledMinutes = TimeCalculator.calculateWorkedMinutes(
            start = workDay.scheduledStart,
            end = workDay.scheduledEnd,
            breakMinutes = 0
        )

        val normalMinutes = if (workedMinutes > scheduledMinutes) {
            scheduledMinutes
        } else {
            workedMinutes
        }

        val extraMinutes = if (workedMinutes > scheduledMinutes) {
            workedMinutes - scheduledMinutes
        } else {
            0
        }

        val nightMinutes = TimeCalculator.calculateNightMinutes(
            start = workDay.realStart,
            end = workDay.realEnd
        )

        val holidayMinutes = if (workDay.isHoliday) {
            workedMinutes
        } else {
            0
        }

        val sundayMinutes = if (workDay.isSunday) {
            workedMinutes
        } else {
            0
        }

        val notes = buildString {
            append("Cálculo laboral generado. ")

            if (extraMinutes > 0) {
                append("Incluye horas extras. ")
            }

            if (nightMinutes > 0) {
                append("Incluye horario nocturno. ")
            }

            if (workDay.isHoliday) {
                append("Día feriado. ")
            }

            if (workDay.isSunday) {
                append("Trabajo dominical. ")
            }
        }

        return LaborCalculationResult(
            workedMinutes = workedMinutes,
            normalMinutes = normalMinutes,
            extraMinutes = extraMinutes,
            nightMinutes = nightMinutes,
            holidayMinutes = holidayMinutes,
            sundayMinutes = sundayMinutes,
            breakMinutes = workDay.breakMinutes,
            notes = notes
        )
    }
}