package com.example.controlhorario.model

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "work_schedule_templates")
data class WorkScheduleTemplate(
    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,
    val nombre: String,
    val descripcion: String,
    val lunes: Boolean,
    val martes: Boolean,
    val miercoles: Boolean,
    val jueves: Boolean,
    val viernes: Boolean,
    val sabado: Boolean,
    val domingo: Boolean,
    val horaEntrada: String,
    val horaSalida: String,
    val tiempoAlmuerzoHoras: Double,
    val jornadaMaximaHoras: Double,
    val horarioFlexible: Boolean
)