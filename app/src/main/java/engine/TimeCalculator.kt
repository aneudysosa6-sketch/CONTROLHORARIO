package com.example.controlhorario.engine

object TimeCalculator {

    fun timeToMinutes(time: String): Int {
        val parts = time.split(":")
        if (parts.size != 2) return 0

        val hour = parts[0].toIntOrNull() ?: 0
        val minute = parts[1].toIntOrNull() ?: 0

        return (hour * 60) + minute
    }

    fun calculateWorkedMinutes(
        start: String,
        end: String,
        breakMinutes: Int
    ): Int {
        val startMinutes = timeToMinutes(start)
        var endMinutes = timeToMinutes(end)

        if (endMinutes < startMinutes) {
            endMinutes += 24 * 60
        }

        val total = endMinutes - startMinutes - breakMinutes

        return if (total < 0) 0 else total
    }

    fun calculateNightMinutes(
        start: String,
        end: String
    ): Int {
        val startMinutes = timeToMinutes(start)
        var endMinutes = timeToMinutes(end)

        if (endMinutes < startMinutes) {
            endMinutes += 24 * 60
        }

        var nightMinutes = 0

        for (minute in startMinutes until endMinutes) {
            val realMinute = minute % (24 * 60)

            val isNight =
                realMinute >= (21 * 60) ||
                        realMinute < (7 * 60)

            if (isNight) {
                nightMinutes++
            }
        }

        return nightMinutes
    }
}