package com.example.controlhorario.ui.punch

import com.example.controlhorario.database.JourneyEntity
import com.example.controlhorario.engine.JourneyAction
import com.example.controlhorario.engine.JourneyStateEngine
import com.example.controlhorario.engine.JourneyStatus

enum class JourneyRemoteAccess {
    LOADING,
    CONFIRMED,
    CACHED,
    PENDING,
    BLOCKED
}

data class JourneyRemotePresentation(
    val access: JourneyRemoteAccess,
    val message: String = ""
) {
    val loadingRemote: Boolean get() = access == JourneyRemoteAccess.LOADING
    val actionsAllowed: Boolean get() = access in setOf(
        JourneyRemoteAccess.CONFIRMED,
        JourneyRemoteAccess.CACHED,
        JourneyRemoteAccess.PENDING
    )

    companion object {
        fun loading() = JourneyRemotePresentation(
            access = JourneyRemoteAccess.LOADING,
            message = "Sincronizando estado de jornada…"
        )

        fun confirmed() = JourneyRemotePresentation(JourneyRemoteAccess.CONFIRMED)

        fun networkFailure(localJourney: JourneyEntity?) = if (localJourney.isValidJourneyCache()) {
            JourneyRemotePresentation(JourneyRemoteAccess.CACHED)
        } else {
            JourneyRemotePresentation(
                access = JourneyRemoteAccess.BLOCKED,
                message = "No se pudo confirmar el estado actual de la jornada. Verifique la conexión."
            )
        }

        fun pendingLocalAction() = JourneyRemotePresentation(
            access = JourneyRemoteAccess.PENDING,
            message = "Hay una acción de jornada pendiente de sincronización."
        )

        fun conflict() = JourneyRemotePresentation(
            access = JourneyRemoteAccess.BLOCKED,
            message = "No se pudo confirmar el estado por un conflicto de sincronización."
        )
    }
}

internal fun JourneyEntity?.isValidJourneyCache(): Boolean =
    this != null && syncStatus == "ENVIADA"

internal object JourneyActionAvailability {
    fun effectiveStatus(localStatus:String?,access:JourneyRemoteAccess):JourneyStatus? {
        if(access !in setOf(JourneyRemoteAccess.CONFIRMED,JourneyRemoteAccess.CACHED,JourneyRemoteAccess.PENDING))return null
        if(localStatus==null)return JourneyStatus.SIN_INICIAR.takeIf{access==JourneyRemoteAccess.CONFIRMED}
        return runCatching{JourneyStatus.valueOf(localStatus)}.getOrNull()
    }

    fun allowedActions(localStatus:String?,access:JourneyRemoteAccess):Set<JourneyAction> =
        effectiveStatus(localStatus,access)?.let(JourneyStateEngine::allowedActions).orEmpty()
}
