package com.example.controlhorario.model

/** Single source of truth for employee codes across Android. */
object EmployeeCodePolicy {
    const val LENGTH = 6
    const val LEGACY_LENGTH = 5
    const val MAX_VALUE = 999_999
    const val ERROR = "El código debe contener 6 dígitos."

    /** UI filtering only. Domain validation remains strict and never silently removes letters. */
    fun sanitizeInput(value: String): String =
        value.filter { it in '0'..'9' }.take(LENGTH)

    /** Accepts official six-digit and transitional five-digit input, returning canonical form. */
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

    /** Canonical first, followed by the exact legacy Room value when one can exist. */
    fun lookupCandidates(value: String): List<String> {
        val canonical = normalizeOrNull(value) ?: return emptyList()
        val legacy = canonical.takeIf { it.startsWith('0') }?.drop(1)
        return listOfNotNull(canonical, legacy).distinct()
    }

    fun matches(storedValue: String, input: String): Boolean {
        val canonical = normalizeOrNull(input) ?: return false
        return normalizeOrNull(storedValue) == canonical
    }

    /** Safe diagnostic representation; employee codes are identifiers, not credentials. */
    fun maskForLog(value: String): String =
        normalizeOrNull(value)?.let { "****${it.takeLast(2)}" } ?: "<invalid>"

    fun nextAfter(lastCode: String?): String {
        if (lastCode == null) return "000001"
        val current = normalizeOrNull(lastCode)
            ?: throw IllegalStateException("Código de empleado existente inválido: $lastCode")
        val next = current.toInt() + 1
        check(next <= MAX_VALUE) { "Se agotó el rango de códigos de empleado (999999)." }
        return next.toString().padStart(LENGTH, '0')
    }

    /** Returns the first ascending provisional code not already present in Room. */
    fun nextAvailableAfter(lastCode: String?, reservedCodes: Collection<String>): String {
        val reserved = reservedCodes.mapNotNull(::normalizeOrNull).toHashSet()
        var candidate = nextAfter(lastCode)
        while (candidate in reserved) candidate = nextAfter(candidate)
        return candidate
    }

    fun append(current: String, digit: String): String =
        if (digit.length == 1 && digit[0] in '0'..'9') sanitizeInput(current + digit) else current
}
