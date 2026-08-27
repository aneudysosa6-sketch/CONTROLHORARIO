package com.example.controlhorario.face

import android.content.Context
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

object PendingFaceEnrollmentButtonPolicy {
    fun visible(count: Int): Boolean = count > 0

    fun label(count: Int): String = when (count) {
        1 -> "Registrar rostro nuevo (1 pendiente)"
        else -> "Registrar rostro nuevo (${count.coerceAtLeast(0)} pendientes)"
    }
}

/** Last server-authoritative count, persisted so camera startup never flashes a false action. */
object PendingFaceEnrollmentCountStore {
    private const val PREFERENCES = "pending_face_enrollment_count_v1"
    private const val KEY_COUNT = "count"
    private var initialized = false
    private val mutableCount = MutableStateFlow(0)
    val count: StateFlow<Int> = mutableCount.asStateFlow()

    @Synchronized
    fun init(context: Context) {
        if (initialized) return
        mutableCount.value = context.applicationContext
            .getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .getInt(KEY_COUNT, 0)
            .coerceAtLeast(0)
        initialized = true
    }

    @Synchronized
    fun update(context: Context, value: Int) {
        init(context)
        val safe = value.coerceAtLeast(0)
        context.applicationContext.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit().putInt(KEY_COUNT, safe).apply()
        mutableCount.value = safe
    }
}
