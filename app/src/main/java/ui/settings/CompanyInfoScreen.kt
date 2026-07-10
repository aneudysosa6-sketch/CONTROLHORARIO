package com.example.controlhorario.ui.settings

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.database.CompanySettingsEntity
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun CompanyInfoScreen(
    viewModel: CompanySettingsViewModel,
    onBack: () -> Unit
) {
    val currentSettings by viewModel.companySettings.collectAsState()

    var nombre by remember { mutableStateOf("") }
    var rnc by remember { mutableStateOf("") }
    var direccion by remember { mutableStateOf("") }
    var telefono by remember { mutableStateOf("") }
    var correo by remember { mutableStateOf("") }
    var mensaje by remember { mutableStateOf("") }

    LaunchedEffect(currentSettings) {
        currentSettings?.let { settings ->
            nombre = settings.companyName
            rnc = settings.rnc
            direccion = settings.address
            telefono = settings.phone
            correo = settings.email
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp)
            .verticalScroll(rememberScrollState())
    ) {
        Text(
            text = "Datos de la empresa",
            style = MaterialTheme.typography.headlineMedium
        )

        Spacer(modifier = Modifier.height(20.dp))

        OSINETTextField(nombre, { nombre = it }, "Nombre de la empresa", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(rnc, { rnc = it }, "RNC", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(direccion, { direccion = it }, "Dirección", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(telefono, { telefono = it }, "Teléfono", Modifier.fillMaxWidth())
        Spacer(modifier = Modifier.height(10.dp))

        OSINETTextField(correo, { correo = it }, "Correo", Modifier.fillMaxWidth())

        Spacer(modifier = Modifier.height(16.dp))

        if (mensaje.isNotEmpty()) {
            Text(mensaje)
            Spacer(modifier = Modifier.height(12.dp))
        }

        OSINETButton(
            text = "💾 Guardar datos",
            onClick = {
                viewModel.saveCompanySettings(
                    CompanySettingsEntity(
                        companyName = nombre.trim(),
                        rnc = rnc.trim(),
                        address = direccion.trim(),
                        phone = telefono.trim(),
                        email = correo.trim()
                    )
                )

                mensaje = "Datos guardados correctamente ✅"
            }
        )

        Spacer(modifier = Modifier.height(12.dp))

        OutlinedButton(
            onClick = onBack,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("⬅ Volver")
        }
    }
}