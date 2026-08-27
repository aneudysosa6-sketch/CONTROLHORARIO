package com.example.controlhorario.ui.labor

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.engine.LaborCalculator
import com.example.controlhorario.engine.LaborWorkDay
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun LaborEngineTestScreen(
    onBack: () -> Unit
) {
    var scheduledStart by remember { mutableStateOf("08:00") }
    var scheduledEnd by remember { mutableStateOf("17:00") }
    var realStart by remember { mutableStateOf("08:00") }
    var realEnd by remember { mutableStateOf("18:00") }
    var breakMinutes by remember { mutableStateOf("60") }

    var isHoliday by remember { mutableStateOf(false) }
    var isSunday by remember { mutableStateOf(false) }

    var resultText by remember { mutableStateOf("") }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
    ) {

        Text("Prueba Motor Laboral RD")

        Spacer(modifier = Modifier.height(16.dp))

        OSINETTextField(scheduledStart, { scheduledStart = it }, "Entrada programada", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(8.dp))

        OSINETTextField(scheduledEnd, { scheduledEnd = it }, "Salida programada", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(8.dp))

        OSINETTextField(realStart, { realStart = it }, "Entrada real", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(8.dp))

        OSINETTextField(realEnd, { realEnd = it }, "Salida real", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(8.dp))

        OSINETTextField(breakMinutes, { breakMinutes = it }, "Pausa en minutos", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(12.dp))

        Checkbox(
            checked = isHoliday,
            onCheckedChange = { isHoliday = it }
        )
        Text("Es feriado")

        Checkbox(
            checked = isSunday,
            onCheckedChange = { isSunday = it }
        )
        Text("Es domingo")

        Spacer(modifier = Modifier.height(12.dp))

        Button(
            modifier = Modifier.fillMaxWidth(),
            onClick = {
                val result = LaborCalculator.calculate(
                    LaborWorkDay(
                        date = "2026-01-01",
                        scheduledStart = scheduledStart,
                        scheduledEnd = scheduledEnd,
                        realStart = realStart,
                        realEnd = realEnd,
                        breakMinutes = breakMinutes.toIntOrNull() ?: 0,
                        isHoliday = isHoliday,
                        isSunday = isSunday
                    )
                )

                resultText = """
                    Minutos trabajados: ${result.workedMinutes}
                    Minutos normales: ${result.normalMinutes}
                    Minutos extras: ${result.extraMinutes}
                    Minutos nocturnos: ${result.nightMinutes}
                    Minutos feriados: ${result.holidayMinutes}
                    Minutos domingo: ${result.sundayMinutes}
                    Pausa: ${result.breakMinutes}
                    
                    ${result.notes}
                """.trimIndent()
            }
        ) {
            Text("Calcular")
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(resultText)

        Spacer(modifier = Modifier.height(24.dp))

        OutlinedButton(
            modifier = Modifier.fillMaxWidth(),
            onClick = onBack
        ) {
            Text("⬅ Volver")
        }
    }
}
