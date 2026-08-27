package com.example.controlhorario.ui.face

import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class TerminalCameraStartupSynchronizerTest {
    @Test
    fun synchronizesPendingEnrollmentsOutsideIdentificationCalibration() = runBlocking {
        var calls = 0
        val synchronizer = TerminalCameraStartupSynchronizer(
            FaceTemplateSyncGateway {
                calls += 1
                true
            },
        )

        assertTrue(synchronizer.synchronizePendingEnrollments())
        assertEquals(1, calls)
    }
}