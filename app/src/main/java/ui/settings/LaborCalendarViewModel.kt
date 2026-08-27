package com.example.controlhorario.ui.settings

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.example.controlhorario.database.LaborCalendarDayEntity
import com.example.controlhorario.repository.LaborCalendarRepository
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

class LaborCalendarViewModel(
    private val repository: LaborCalendarRepository
) : ViewModel() {

    val laborCalendarDays: StateFlow<List<LaborCalendarDayEntity>> =
        repository.getAllDays()
            .stateIn(
                scope = viewModelScope,
                started = SharingStarted.WhileSubscribed(5000),
                initialValue = emptyList()
            )

    fun addLaborDay(
        date: String,
        title: String,
        type: String,
        description: String,
        isPaid: Boolean
    ) {
        if (date.isBlank() || title.isBlank() || type.isBlank()) return

        viewModelScope.launch {
            repository.insertDay(
                LaborCalendarDayEntity(
                    date = date.trim(),
                    title = title.trim(),
                    type = type.trim(),
                    description = description.trim(),
                    isPaid = isPaid
                )
            )
        }
    }

    fun preloadDominicanHolidays(year: Int) {
        val holidays = listOf(
            LaborCalendarDayEntity(
                date = "$year-01-01",
                title = "Año Nuevo",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-01-06",
                title = "Día de los Santos Reyes",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-01-21",
                title = "Día de Nuestra Señora de la Altagracia",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-01-26",
                title = "Día de Duarte",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-02-27",
                title = "Día de la Independencia Nacional",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-05-01",
                title = "Día del Trabajo",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-08-16",
                title = "Día de la Restauración",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-09-24",
                title = "Día de Nuestra Señora de las Mercedes",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-11-06",
                title = "Día de la Constitución",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            ),
            LaborCalendarDayEntity(
                date = "$year-12-25",
                title = "Día de Navidad",
                type = "Feriado RD",
                description = "Día feriado nacional",
                isPaid = true
            )
        )

        viewModelScope.launch {
            holidays.forEach { holiday ->
                repository.insertDay(holiday)
            }
        }
    }

    fun updateLaborDay(day: LaborCalendarDayEntity) {
        if (day.date.isBlank() || day.title.isBlank() || day.type.isBlank()) return

        viewModelScope.launch {
            repository.updateDay(day)
        }
    }

    fun deleteLaborDay(day: LaborCalendarDayEntity) {
        viewModelScope.launch {
            repository.deleteDay(day)
        }
    }
}