package com.example.controlhorario.ui.whatsapp

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.example.controlhorario.ui.components.OSINETButton
import com.example.controlhorario.ui.components.OSINETTextField

@Composable
fun WhatsAppN8NScreen(
    viewModel: WhatsAppN8NViewModel,
    onBack: () -> Unit
) {
    val messages by viewModel.messages.collectAsState()
    var phone by remember { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(24.dp)) {
        Text("WhatsApp / N8N", style = MaterialTheme.typography.headlineSmall)
        Text("Cola local de mensajes lista para que N8N los consuma por integración futura.")
        Spacer(Modifier.height(16.dp))
        OSINETTextField(phone, { phone = it }, "Teléfono", Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        OSINETTextField(message, { message = it }, "Mensaje", Modifier.fillMaxWidth())
        Spacer(Modifier.height(12.dp))
        OSINETButton("Agregar a cola", { viewModel.queueMessage(phone, message) })
        Spacer(Modifier.height(8.dp))
        OSINETButton("Volver", onBack)
        Spacer(Modifier.height(16.dp))
        Text("Mensajes en cola: ${messages.size}")
    }
}
