package com.example.controlhorario.engine

data class LaborCalculationResult(
    val workedMinutes: Int = 0,
    val normalMinutes: Int = 0,
    val extraMinutes: Int = 0,
    val nightMinutes: Int = 0,
    val holidayMinutes: Int = 0,
    val sundayMinutes: Int = 0,
    val breakMinutes: Int = 0,
    val notes: String = ""
)