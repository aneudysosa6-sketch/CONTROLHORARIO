package com.example.controlhorario.face

import java.nio.ByteBuffer
import java.util.concurrent.atomic.AtomicBoolean

object FaceFrameSafety {
    fun copyLuma(buffer: ByteBuffer?, width: Int, height: Int, rowStride: Int, pixelStride: Int): ByteArray {
        require(buffer != null) { "y_plane_buffer_null" }
        require(width > 0 && height > 0) { "invalid_frame_size" }
        require(rowStride > 0 && pixelStride > 0) { "invalid_plane_stride" }
        val source = buffer.duplicate()
        val base = source.position()
        val available = source.remaining()
        val lastIndex = (height - 1).toLong() * rowStride + (width - 1).toLong() * pixelStride
        require(lastIndex < available.toLong()) { "incomplete_y_plane available=$available required=${lastIndex + 1}" }
        return ByteArray(width * height).also { output ->
            var target = 0
            for (y in 0 until height) {
                val row = base + y * rowStride
                for (x in 0 until width) output[target++] = source.get(row + x * pixelStride)
            }
        }
    }
}

class FaceFrameGate {
    private val processing = AtomicBoolean(false)
    fun tryAcquire(): Boolean = processing.compareAndSet(false, true)
    fun release() { processing.set(false) }
    fun isProcessing(): Boolean = processing.get()
}

class CloseOnce(private val closeAction: () -> Unit) {
    private val closed = AtomicBoolean(false)
    fun close() { if (closed.compareAndSet(false, true)) closeAction() }
}
