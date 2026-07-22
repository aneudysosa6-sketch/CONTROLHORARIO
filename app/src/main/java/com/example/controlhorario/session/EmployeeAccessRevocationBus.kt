package com.example.controlhorario.session

import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.asSharedFlow

/** Forces every administrative route to leave the back stack after a remote termination. */
object EmployeeAccessRevocationBus {
    private val mutableEvents = MutableSharedFlow<Unit>(extraBufferCapacity = 1)
    val events = mutableEvents.asSharedFlow()

    fun notifyRevoked() {
        mutableEvents.tryEmit(Unit)
    }
}
