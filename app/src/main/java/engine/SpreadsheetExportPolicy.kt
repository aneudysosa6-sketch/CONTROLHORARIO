package com.example.controlhorario.engine

object SpreadsheetExportPolicy {
    private val dangerousPrefixes = setOf('=', '+', '-', '@')

    fun neutralize(value: String): String {
        val firstVisible = value.firstOrNull { !it.isWhitespace() }
        return if (firstVisible in dangerousPrefixes) "'" + value else value
    }

    fun csvCell(value: String): String =
        "\"" + neutralize(value).replace("\"", "\"\"") + "\""
}