package com.example.controlhorario.face

import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Process-local revision for the decrypted 1:N template cache.
 *
 * Room remains the source of truth. Writers increment this revision only after a face row has
 * changed so an already-visible identification screen cannot keep using its old decrypted copy.
 * A screen created after the change reads Room normally and does not need the missed event.
 */
object FaceTemplateInvalidationBus {
    private val lock = Any()
    private val mutableRevision = MutableStateFlow(0L)

    val revisions: StateFlow<Long> = mutableRevision.asStateFlow()
    val currentRevision: Long
        get() = mutableRevision.value

    fun invalidate(): Long = synchronized(lock) {
        val next = mutableRevision.value + 1L
        mutableRevision.value = next
        next
    }
}
