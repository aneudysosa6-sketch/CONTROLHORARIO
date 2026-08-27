package com.example.controlhorario.model

import kotlin.random.Random

object EmployeeCodePolicy {
    const val LENGTH = 6
    const val LEGACY_LENGTH = 5
    const val MAX_VALUE = 999_999
    const val ERROR = "El codigo debe contener 6 digitos."

    fun sanitizeInput(value: String): String =
        value.filter { it in '0'..'9' }.take(LENGTH)

    fun normalizeOrNull(value: String): String? {
        if (value.length !in setOf(LEGACY_LENGTH, LENGTH) || value.any { it !in '0'..'9' }) {
            return null
        }
        val number = value.toIntOrNull()?.takeIf { it in 1..MAX_VALUE } ?: return null
        return number.toString().padStart(LENGTH, '0')
    }

    fun isValid(value: String): Boolean = normalizeOrNull(value) != null

    fun isCanonical(value: String): Boolean =
        value.length == LENGTH && normalizeOrNull(value) == value

    fun lookupCandidates(value: String): List<String> {
        val canonical = normalizeOrNull(value) ?: return emptyList()
        val legacy = canonical.takeIf { it.startsWith('0') }?.drop(1)
        return listOfNotNull(canonical, legacy).distinct()
    }

    fun matches(storedValue: String, input: String): Boolean {
        val canonical = normalizeOrNull(input) ?: return false
        return normalizeOrNull(storedValue) == canonical
    }

    fun maskForLog(value: String): String =
        normalizeOrNull(value)?.let { "****" + it.takeLast(2) } ?: "<invalid>"

    fun randomAvailable(
        reservedCodes: Collection<String>,
        random: Random = Random.Default,
    ): String {
        val reserved = reservedCodes.mapNotNull(::normalizeOrNull).toHashSet()
        check(reserved.size < MAX_VALUE) {
            "Se agoto el rango de codigos de empleado (999999)."
        }
        val start = random.nextInt(from = 1, until = MAX_VALUE + 1)
        repeat(MAX_VALUE) { offset ->
            val candidate = ((start - 1 + offset) % MAX_VALUE) + 1
            val code = candidate.toString().padStart(LENGTH, '0')
            if (code !in reserved) return code
        }
        error("Se agoto el rango de codigos de empleado (999999).")
    }

    fun append(current: String, digit: String): String =
        if (digit.length == 1 && digit[0] in '0'..'9') sanitizeInput(current + digit) else current
}