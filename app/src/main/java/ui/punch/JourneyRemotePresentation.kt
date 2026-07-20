package com.example.controlhorario.ui.punch

import com.example.controlhorario.database.JourneyEntity

enum class JourneyRemoteAccess {
    LOADING,
    CONFIRMED,
    CACHED,
    BLOCKED
}

data class JourneyRemotePresentation(
    val access: JourneyRemoteAccess,
    val message: String = ""
) {
    val loadingRemote: Boolean get() = access == JourneyRemoteAccess.LOADING
    val actionsAllowed: Boolean get() = access == JourneyRemoteAccess.CONFIRMED || access == JourneyRemoteAccess.CACHED

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
            access = JourneyRemoteAccess.BLOCKED,
            message = "Hay una acción de jornada pendiente de sincronización. Verifique la conexión."
        )

        fun conflict() = JourneyRemotePresentation(
            access = JourneyRemoteAccess.BLOCKED,
            message = "No se pudo confirmar el estado por un conflicto de sincronización."
        )
    }
}

internal fun JourneyEntity?.isValidJourneyCache(): Boolean =
    this != null && syncStatus == "ENVIADA"
