package com.example.controlhorario.database

import androidx.room.Entity
import androidx.room.PrimaryKey

@Entity(tableName = "company_settings")
data class CompanySettingsEntity(
    @PrimaryKey
    val id: Int = 1,
    val companyName: String = "",
    val rnc: String = "",
    val address: String = "",
    val phone: String = "",
    val email: String = ""
)