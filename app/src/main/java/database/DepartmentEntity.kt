package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "departments")
data class DepartmentEntity(

    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,

    val branchId: Int,

    val name: String,

    val code: String,

    val description: String,

    val manager: String,

    val active: Boolean = true
)