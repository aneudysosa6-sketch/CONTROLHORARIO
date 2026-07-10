package com.example.controlhorario.engine

data class LaborWorkDay(
    val date: String,
    val scheduledStart: String,
    val scheduledEnd: String,
    val realStart: String,
    val realEnd: String,
    val breakMinutes: Int = 0,
    val isHoliday: Boolean = false,
    val isSunday: Boolean = false
)