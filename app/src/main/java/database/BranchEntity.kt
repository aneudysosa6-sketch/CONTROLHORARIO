package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "branches")
data class BranchEntity(

    @PrimaryKey(autoGenerate = true)
    val id: Int = 0,

    val name: String,

    val code: String,

    val address: String,

    val city: String,

    val province: String,

    val phone: String,

    val manager: String,

    val active: Boolean = true
)