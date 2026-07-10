package com.example.controlhorario.engine

object AttendanceStateMachine {

    fun getCurrentState(actions: List<String>): AttendanceState {
        if (actions.isEmpty()) {
            return AttendanceState.SIN_JORNADA
        }

        return when (actions.last()) {
            AttendanceAction.INICIO_JORNADA.name -> AttendanceState.TRABAJANDO
            AttendanceAction.PAUSA.name -> AttendanceState.EN_PAUSA
            AttendanceAction.REANUDAR.name -> AttendanceState.TRABAJANDO
            AttendanceAction.FIN_JORNADA.name -> AttendanceState.FINALIZADA
            else -> AttendanceState.SIN_JORNADA
        }
    }

    fun canRegisterAction(
        currentState: AttendanceState,
        action: AttendanceAction
    ): Boolean {
        return when (currentState) {

            AttendanceState.SIN_JORNADA -> {
                action == AttendanceAction.INICIO_JORNADA
            }

            AttendanceState.TRABAJANDO -> {
                action == AttendanceAction.PAUSA ||
                        action == AttendanceAction.FIN_JORNADA
            }

            AttendanceState.EN_PAUSA -> {
                action == AttendanceAction.REANUDAR ||
                        action == AttendanceAction.FIN_JORNADA
            }

            AttendanceState.FINALIZADA -> {
                false
            }
        }
    }

    fun getErrorMessage(
        currentState: AttendanceState,
        action: AttendanceAction
    ): String {
        return when (currentState) {

            AttendanceState.SIN_JORNADA -> {
                if (action != AttendanceAction.INICIO_JORNADA) {
                    "No puedes registrar esta acción porque la jornada no ha iniciado."
                } else {
                    ""
                }
            }

            AttendanceState.TRABAJANDO -> {
                if (
                    action != AttendanceAction.PAUSA &&
                    action != AttendanceAction.FIN_JORNADA
                ) {
                    "Esta acción no es válida mientras el empleado está trabajando."
                } else {
                    ""
                }
            }

            AttendanceState.EN_PAUSA -> {
                if (
                    action != AttendanceAction.REANUDAR &&
                    action != AttendanceAction.FIN_JORNADA
                ) {
                    "El empleado está en pausa. Solo puede reanudar o finalizar jornada."
                } else {
                    ""
                }
            }

            AttendanceState.FINALIZADA -> {
                "La jornada de hoy ya fue finalizada."
            }
        }
    }
}