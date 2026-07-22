package com.example.controlhorario.face

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceTemplateInvalidationBusTest {
    @Test
    fun `invalidation publishes a strictly newer revision`() {
        val before = FaceTemplateInvalidationBus.currentRevision

        val published = FaceTemplateInvalidationBus.invalidate()

        assertTrue(published > before)
        assertEquals(published, FaceTemplateInvalidationBus.currentRevision)
        assertEquals(published, FaceTemplateInvalidationBus.revisions.value)
    }
}
