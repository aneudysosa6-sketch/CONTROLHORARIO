package com.example.controlhorario.ui.punch

import com.example.controlhorario.engine.JourneyAction
import org.junit.Assert.assertEquals
import org.junit.Test

class TerminalJourneySpeechTest {
    @Test
    fun approvedPhrasesUseOnlyFirstName() {
        assertEquals(
            "Bienvenido, Ana.",
            TerminalJourneySpeech.phrase(JourneyAction.INICIAR, "Ana María Prueba"),
        )
        assertEquals(
            "Recuerda volver a la hora asignada, Ana.",
            TerminalJourneySpeech.phrase(JourneyAction.PAUSAR, "Ana María Prueba"),
        )
        assertEquals(
            "Gracias por volver, Ana.",
            TerminalJourneySpeech.phrase(JourneyAction.REANUDAR, "Ana María Prueba"),
        )
        assertEquals(
            "Adiós, que tengas un excelente resto del día, Ana.",
            TerminalJourneySpeech.phrase(JourneyAction.FINALIZAR, "Ana María Prueba"),
        )
    }
}