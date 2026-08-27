package com.example.controlhorario.ui.punch

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import android.util.Log
import com.example.controlhorario.BuildConfig
import com.example.controlhorario.engine.JourneyAction
import java.util.Locale
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap

internal object TerminalJourneySpeech {
    fun phrase(action: JourneyAction, employeeName: String): String {
        val firstName = employeeName.trim()
            .split(Regex("\\s+"))
            .firstOrNull()
            ?.takeIf(String::isNotBlank)
            ?: "empleado"
        return when (action) {
            JourneyAction.INICIAR -> "Bienvenido, $firstName."
            JourneyAction.PAUSAR -> "Recuerda volver a la hora asignada, $firstName."
            JourneyAction.REANUDAR -> "Gracias por volver, $firstName."
            JourneyAction.FINALIZAR ->
                "Adiós, que tengas un excelente resto del día, $firstName."
        }
    }
}

/** Process-screen speaker: survives navigation back to camera so speech is not truncated. */
internal class TerminalJourneySpeaker(context: Context) : AutoCloseable {
    private val lock = Any()
    private val actionsByUtterance = ConcurrentHashMap<String, JourneyAction>()
    private var engine: TextToSpeech? = null
    private var ready = false
    private var closed = false
    private var pending: PendingSpeech? = null

    init {
        val created = TextToSpeech(context.applicationContext) { status ->
            onInitialized(status)
        }
        engine = created
        created.setOnUtteranceProgressListener(
            object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) {
                    log(utteranceId, "START")
                }

                override fun onDone(utteranceId: String?) {
                    log(utteranceId, "DONE")
                    utteranceId?.let(actionsByUtterance::remove)
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) {
                    log(utteranceId, "ERROR")
                    utteranceId?.let(actionsByUtterance::remove)
                }
            }
        )
    }

    fun speak(action: JourneyAction, employeeName: String) {
        val request = PendingSpeech(
            action = action,
            phrase = TerminalJourneySpeech.phrase(action, employeeName),
        )
        synchronized(lock) {
            if (closed) return
            if (!ready) {
                pending = request
                if (BuildConfig.DEBUG) Log.i(TAG, "action=" + action.name + " status=PENDING_ENGINE")
                return
            }
        }
        speakNow(request)
    }

    private fun onInitialized(status: Int) {
        val currentEngine = engine
        if (status != TextToSpeech.SUCCESS || currentEngine == null) {
            if (BuildConfig.DEBUG) Log.e(TAG, "action=NONE status=INIT_ERROR")
            return
        }
        val languageResult = currentEngine.setLanguage(Locale("es", "BO"))
        if (
            languageResult == TextToSpeech.LANG_MISSING_DATA ||
            languageResult == TextToSpeech.LANG_NOT_SUPPORTED
        ) {
            if (BuildConfig.DEBUG) Log.e(TAG, "action=NONE status=LANGUAGE_ERROR")
            return
        }

        val pendingRequest = synchronized(lock) {
            if (closed) return
            ready = true
            pending.also { pending = null }
        }
        if (BuildConfig.DEBUG) Log.i(TAG, "action=NONE status=READY")
        pendingRequest?.let(::speakNow)
    }

    private fun speakNow(request: PendingSpeech) {
        val utteranceId = "journey-" + request.action.name + "-" + UUID.randomUUID()
        actionsByUtterance[utteranceId] = request.action
        val result = engine?.speak(
            request.phrase,
            TextToSpeech.QUEUE_FLUSH,
            null,
            utteranceId,
        ) ?: TextToSpeech.ERROR
        if (result == TextToSpeech.ERROR) {
            actionsByUtterance.remove(utteranceId)
            if (BuildConfig.DEBUG) Log.e(TAG, "action=" + request.action.name + " status=QUEUE_ERROR")
        } else {
            if (BuildConfig.DEBUG) Log.i(TAG, "action=" + request.action.name + " status=QUEUED")
        }
    }

    private fun log(utteranceId: String?, status: String) {
        if (!BuildConfig.DEBUG) return
        val action = utteranceId?.let(actionsByUtterance::get)
        Log.i(TAG, "action=" + (action?.name ?: "UNKNOWN") + " status=" + status)
    }

    override fun close() {
        synchronized(lock) {
            closed = true
            ready = false
            pending = null
        }
        actionsByUtterance.clear()
        engine?.stop()
        engine?.shutdown()
        engine = null
    }

    private data class PendingSpeech(
        val action: JourneyAction,
        val phrase: String,
    )

    private companion object {
        const val TAG = "TERMINAL_TTS"
    }
}