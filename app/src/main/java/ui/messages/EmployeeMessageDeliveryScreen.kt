package com.example.controlhorario.ui.messages

import android.media.MediaPlayer
import android.speech.tts.TextToSpeech
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.example.controlhorario.attendance.EmployeeMessagePayload
import com.example.controlhorario.database.DatabaseProvider
import com.example.controlhorario.messages.EmployeeMessageInbox
import com.example.controlhorario.messages.EmployeeMessageReceiptScheduler
import kotlinx.coroutines.delay
import java.util.Locale

@Composable
fun EmployeeMessageDeliveryScreen(
    message: EmployeeMessagePayload,
    onCompleted: () -> Unit
) {
    val context = LocalContext.current
    var accepted by rememberSaveable(message.id) { mutableStateOf(false) }
    var playbackRevision by rememberSaveable(message.id) { mutableIntStateOf(0) }
    var speech by remember(message.id) { mutableStateOf<TextToSpeech?>(null) }
    var voiceEnabled by remember(message.id) { mutableStateOf<Boolean?>(null) }

    LaunchedEffect(message.id) {
        voiceEnabled = runCatching {
            DatabaseProvider.getDatabase(context.applicationContext)
                .deviceEnrollmentDao()
                .current()
                ?.voiceEnabled
        }.getOrNull() ?: true
    }

    DisposableEffect(message.id, voiceEnabled) {
        var engine: TextToSpeech? = null
        if (voiceEnabled == true && message.type == "VOZ_SISTEMA") {
            engine = TextToSpeech(context.applicationContext) { status ->
                if (status == TextToSpeech.SUCCESS) {
                    engine?.language = Locale("es")
                    engine?.speak(message.text.orEmpty(), TextToSpeech.QUEUE_FLUSH, null, message.id)
                }
            }
            speech = engine
        }
        onDispose {
            engine?.stop()
            engine?.shutdown()
            speech = null
        }
    }

    DisposableEffect(message.id, playbackRevision, voiceEnabled) {
        var player: MediaPlayer? = null
        if (voiceEnabled == true && message.type == "VOZ_GRABADA" && !message.audioUrl.isNullOrBlank()) {
            player = MediaPlayer().apply {
                setDataSource(message.audioUrl)
                setOnPreparedListener { it.start() }
                setOnErrorListener { _, _, _ -> true }
                prepareAsync()
            }
        }
        onDispose {
            player?.stop()
            player?.release()
        }
    }

    LaunchedEffect(accepted) {
        if (accepted) {
            delay(2_000)
            onCompleted()
        }
    }

    Surface(modifier = Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
        Column(
            modifier = Modifier.fillMaxSize().padding(horizontal = 28.dp, vertical = 36.dp),
            verticalArrangement = Arrangement.Center
        ) {
            Text("MENSAJE PARA EL EMPLEADO", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(12.dp))
            Text(
                if (accepted) "MENSAJE RECIBIDO" else "Tiene un mensaje pendiente",
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Bold
            )
            Spacer(Modifier.height(20.dp))
            if (!message.text.isNullOrBlank()) {
                Column(
                    modifier = Modifier.heightIn(max = 320.dp).verticalScroll(rememberScrollState())
                ) {
                    Text(message.text, style = MaterialTheme.typography.bodyLarge)
                }
            } else {
                Text("Mensaje de voz grabado (" + message.audioDurationSeconds + " s)")
            }
            if (voiceEnabled == false && message.type in setOf("VOZ_SISTEMA", "VOZ_GRABADA")) {
                Spacer(Modifier.height(12.dp))
                Text("La reproducción de voz está desactivada para este terminal.")
            }
            Spacer(Modifier.height(24.dp))
            if (!accepted && voiceEnabled == true && message.type in setOf("VOZ_SISTEMA", "VOZ_GRABADA")) {
                OutlinedButton(
                    onClick = {
                        if (voiceEnabled == true && message.type == "VOZ_SISTEMA") {
                            speech?.speak(
                                message.text.orEmpty(),
                                TextToSpeech.QUEUE_FLUSH,
                                null,
                                message.id
                            )
                        } else {
                            playbackRevision += 1
                        }
                    }
                ) {
                    Text("Repetir mensaje")
                }
                Spacer(Modifier.height(12.dp))
            }
            Button(
                enabled = !accepted,
                onClick = {
                    if (accepted) return@Button
                    speech?.stop()
                    EmployeeMessageInbox.acknowledgeForReceipt(context.applicationContext)
                    EmployeeMessageReceiptScheduler.enqueue(context.applicationContext)
                    accepted = true
                }
            ) {
                Text("MENSAJE RECIBIDO")
            }
        }
    }
}