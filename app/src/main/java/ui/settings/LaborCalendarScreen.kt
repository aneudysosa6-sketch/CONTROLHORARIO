package com.example.controlhorario.ui.settings

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import java.util.Calendar
import com.example.controlhorario.ui.components.OSINETTextField

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LaborCalendarScreen(
    viewModel: LaborCalendarViewModel,
    onBack: () -> Unit
) {
    val days by viewModel.laborCalendarDays.collectAsState()
    val calendar = Calendar.getInstance()

    var selectedYear by remember { mutableIntStateOf(calendar.get(Calendar.YEAR)) }
    var selectedMonth by remember { mutableIntStateOf(calendar.get(Calendar.MONTH)) }

    var selectedDate by remember { mutableStateOf("") }
    var title by remember { mutableStateOf("") }
    var type by remember { mutableStateOf("Feriado") }
    var description by remember { mutableStateOf("") }
    var paid by remember { mutableStateOf(true) }

    val monthName = getMonthName(selectedMonth)
    val monthDays = getMonthDays(selectedYear, selectedMonth)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Calendario Laboral") }
            )
        }
    ) { padding ->

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp)
        ) {

            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    OutlinedButton(
                        onClick = {
                            if (selectedMonth == 0) {
                                selectedMonth = 11
                                selectedYear -= 1
                            } else {
                                selectedMonth -= 1
                            }
                        }
                    ) {
                        Text("◀")
                    }

                    Text(
                        text = "$monthName $selectedYear",
                        style = MaterialTheme.typography.titleLarge
                    )

                    OutlinedButton(
                        onClick = {
                            if (selectedMonth == 11) {
                                selectedMonth = 0
                                selectedYear += 1
                            } else {
                                selectedMonth += 1
                            }
                        }
                    ) {
                        Text("▶")
                    }
                }

                Spacer(modifier = Modifier.height(12.dp))

                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        viewModel.preloadDominicanHolidays(selectedYear)
                    }
                ) {
                    Text("🇩🇴 Cargar feriados RD $selectedYear")
                }

                Spacer(modifier = Modifier.height(16.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    listOf("D", "L", "M", "M", "J", "V", "S").forEach {
                        Text(
                            text = it,
                            modifier = Modifier.width(42.dp)
                        )
                    }
                }

                Spacer(modifier = Modifier.height(8.dp))

                monthDays.chunked(7).forEach { week ->

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        week.forEach { day ->

                            val dateText = if (day > 0) {
                                formatDate(selectedYear, selectedMonth, day)
                            } else {
                                ""
                            }

                            val hasEvent = days.any { it.date == dateText }

                            Column(
                                modifier = Modifier
                                    .width(42.dp)
                                    .height(52.dp)
                                    .border(1.dp, MaterialTheme.colorScheme.outline)
                                    .clickable(enabled = day > 0) {
                                        selectedDate = dateText
                                    }
                                    .padding(4.dp)
                            ) {
                                Text(
                                    text = if (day > 0) day.toString() else ""
                                )

                                if (hasEvent) {
                                    Text("●")
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(6.dp))
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = "Nuevo día laboral",
                    style = MaterialTheme.typography.titleMedium
                )

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(selectedDate, { selectedDate = it }, "Fecha (AAAA-MM-DD)", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(title, { title = it }, "Nombre", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(type, { type = it }, "Tipo", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                OSINETTextField(description, { description = it }, "Descripción", Modifier.fillMaxWidth())

                Spacer(modifier = Modifier.height(8.dp))

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("Día remunerado")

                    Checkbox(
                        checked = paid,
                        onCheckedChange = { paid = it }
                    )
                }

                Spacer(modifier = Modifier.height(12.dp))

                Button(
                    modifier = Modifier.fillMaxWidth(),
                    onClick = {
                        viewModel.addLaborDay(
                            date = selectedDate,
                            title = title,
                            type = type,
                            description = description,
                            isPaid = paid
                        )

                        selectedDate = ""
                        title = ""
                        type = "Feriado"
                        description = ""
                        paid = true
                    }
                ) {
                    Text("Guardar día")
                }

                Spacer(modifier = Modifier.height(12.dp))

                OutlinedButton(
                    onClick = onBack,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("⬅ Volver")
                }

                Spacer(modifier = Modifier.height(20.dp))

                Text(
                    text = "Días registrados",
                    style = MaterialTheme.typography.titleMedium
                )

                Spacer(modifier = Modifier.height(8.dp))
            }

            items(days) { day ->

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    elevation = CardDefaults.cardElevation(3.dp)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        Column(
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(day.date)
                            Text(day.title)
                            Text(day.type)
                            Text(day.description)

                            Text(
                                if (day.isPaid)
                                    "Remunerado"
                                else
                                    "No remunerado"
                            )
                        }

                        Button(
                            onClick = {
                                viewModel.deleteLaborDay(day)
                            }
                        ) {
                            Text("Eliminar")
                        }
                    }
                }
            }
        }
    }
}

private fun getMonthName(month: Int): String {
    return when (month) {
        0 -> "Enero"
        1 -> "Febrero"
        2 -> "Marzo"
        3 -> "Abril"
        4 -> "Mayo"
        5 -> "Junio"
        6 -> "Julio"
        7 -> "Agosto"
        8 -> "Septiembre"
        9 -> "Octubre"
        10 -> "Noviembre"
        11 -> "Diciembre"
        else -> ""
    }
}

private fun getMonthDays(year: Int, month: Int): List<Int> {
    val calendar = Calendar.getInstance()
    calendar.set(year, month, 1)

    val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK)
    val maxDays = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)

    val emptyDays = firstDayOfWeek - 1
    val days = mutableListOf<Int>()

    repeat(emptyDays) {
        days.add(0)
    }

    for (day in 1..maxDays) {
        days.add(day)
    }

    while (days.size % 7 != 0) {
        days.add(0)
    }

    return days
}

private fun formatDate(year: Int, month: Int, day: Int): String {
    val realMonth = month + 1
    val monthText = if (realMonth < 10) "0$realMonth" else realMonth.toString()
    val dayText = if (day < 10) "0$day" else day.toString()

    return "$year-$monthText-$dayText"
}
