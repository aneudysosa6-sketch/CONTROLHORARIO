package com.example.controlhorario.face

import java.nio.ByteBuffer
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceFrameSafetyTest {
    @Test fun copiesPaddedRowsAndPixelStride() {
        val source = byteArrayOf(1, 9, 2, 9, 0, 0, 3, 9, 4, 9, 0, 0)
        assertArrayEquals(byteArrayOf(1, 2, 3, 4), FaceFrameSafety.copyLuma(ByteBuffer.wrap(source), 2, 2, 6, 2))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsIncompleteBuffer() = Unit.also {
        FaceFrameSafety.copyLuma(ByteBuffer.wrap(byteArrayOf(1, 2, 3)), 2, 2, 2, 1)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsNullBuffer() = Unit.also { FaceFrameSafety.copyLuma(null, 2, 2, 2, 1) }

    @Test fun blocksConcurrentFramesAndRecovers() {
        val gate = FaceFrameGate()
        assertTrue(gate.tryAcquire())
        assertFalse(gate.tryAcquire())
        gate.release()
        assertTrue(gate.tryAcquire())
    }

    @Test fun closesExactlyOnce() {
        var closes = 0
        val closeOnce = CloseOnce { closes++ }
        closeOnce.close(); closeOnce.close()
        assertEquals(1, closes)
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsInvalidEmbeddingDimension() = Unit.also {
        with(FaceEmbeddingEngine) { FloatArray(127).normalized() }
    }
}
