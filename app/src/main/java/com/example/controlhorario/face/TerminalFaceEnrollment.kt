package com.example.controlhorario.face

data class TerminalFaceEnrollmentLookup(
    val employeeRemoteId: String,
    val employeeCode: String,
    val employeeName: String,
    val modelName: String,
    val embeddingDimension: Int,
)

data class TerminalFaceEnrollmentConfirmation(
    val employeeRemoteId: String,
    val enrolledAt: String,
    val modelName: String,
    val embeddingDimension: Int,
    val embedding: FloatArray,
    val pendingFaceCount: Int,
)

interface TerminalFaceEnrollmentGateway {
    suspend fun lookup(employeeCode: String): TerminalFaceEnrollmentLookup

    suspend fun complete(
        lookup: TerminalFaceEnrollmentLookup,
        embedding: FloatArray,
        livenessVerified: Boolean,
    ): TerminalFaceEnrollmentConfirmation
}

class TerminalFaceEnrollmentException(
    val errorCode: String,
    val userMessage: String = TerminalFaceEnrollmentMessages.forCode(errorCode),
) : IllegalStateException(userMessage)

object TerminalFaceEnrollmentMessages {
    const val OFFLINE = "Sin conexión. Inténtalo nuevamente cuando vuelva Internet."
    const val SCHEDULE_DAY_OFF = "SUPERVISOR DEBE ASIGNAR HORARIO Y DÍA LIBRE"
    const val DUPLICATE = "Rostro ya registrado en otro empleado"
    const val ALREADY_REGISTERED =
        "Este empleado ya tiene un rostro registrado. Solicite a un administrador que lo elimine antes de reemplazarlo."

    fun forCode(code: String): String = when (code) {
        "NETWORK_UNAVAILABLE" -> OFFLINE
        "SCHEDULE_DAYOFF_REQUIRED" -> SCHEDULE_DAY_OFF
        "FACE_DUPLICATE" -> DUPLICATE
        "FACE_ALREADY_REGISTERED", "FACE_ENROLLMENT_REPLAY_REVOKED" -> ALREADY_REGISTERED
        "EMPLOYEE_NOT_FOUND" -> "No existe un empleado con ese código."
        "TERMINAL_SCOPE_DENIED" -> "El empleado no pertenece al alcance de este Terminal."
        "EMPLOYEE_NOT_ELIGIBLE" -> "El empleado no está habilitado para registrar jornada."
        "DEVICE_REVOKED", "INVALID_DEVICE_CREDENTIAL" -> "TERMINAL NO AUTORIZADO"
        "FACE_LIVENESS_INCOMPLETE" -> "No fue posible validar la prueba de vida."
        "FACE_EMBEDDING_INVALID" -> "No fue posible validar la plantilla facial."
        else -> "No fue posible completar el registro facial."
    }
}
