package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "labor_calendar_days")
data class LaborCalendarDayEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val date: String,
    val title: String,
    val type: String,
    val description: String = "",
    val isPaid: Boolean = true
)