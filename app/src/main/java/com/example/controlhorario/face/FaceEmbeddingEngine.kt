package com.example.controlhorario.face

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Rect
import org.tensorflow.lite.Interpreter
import java.io.FileInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.channels.FileChannel
import kotlin.math.sqrt

class FaceEmbeddingEngine(context: Context) : AutoCloseable {
    private val interpreter = Interpreter(
        context.assets.openFd(MODEL_NAME).let { descriptor ->
            FileInputStream(descriptor.fileDescriptor).channel.map(
                FileChannel.MapMode.READ_ONLY,
                descriptor.startOffset,
                descriptor.declaredLength
            )
        },
        Interpreter.Options().setNumThreads(4)
    )

    fun embedding(frame: Bitmap, bounds: Rect): FloatArray {
        val crop = Bitmap.createBitmap(frame, bounds.left.coerceAtLeast(0), bounds.top.coerceAtLeast(0),
            bounds.width().coerceAtMost(frame.width - bounds.left.coerceAtLeast(0)),
            bounds.height().coerceAtMost(frame.height - bounds.top.coerceAtLeast(0)))
        val scaled = Bitmap.createScaledBitmap(crop, INPUT_SIZE, INPUT_SIZE, true)
        val input = ByteBuffer.allocateDirect(INPUT_SIZE * INPUT_SIZE * 3 * Float.SIZE_BYTES).order(ByteOrder.nativeOrder())
        val pixels = IntArray(INPUT_SIZE * INPUT_SIZE)
        scaled.getPixels(pixels, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
        pixels.forEach { pixel ->
            input.putFloat(((pixel shr 16 and 0xff) - 127.5f) / 128f)
            input.putFloat(((pixel shr 8 and 0xff) - 127.5f) / 128f)
            input.putFloat(((pixel and 0xff) - 127.5f) / 128f)
        }
        return Array(1) { FloatArray(EMBEDDING_DIMENSION) }.also { interpreter.run(input, it) }[0].normalized()
    }

    override fun close() = interpreter.close()

    companion object {
        const val MODEL_NAME = "facenet.tflite"
        const val INPUT_SIZE = 160
        const val EMBEDDING_DIMENSION = 128
        const val COSINE_THRESHOLD = 0.75f
        fun cosine(a: FloatArray, b: FloatArray): Float = a.indices.sumOf { (a[it] * b[it]).toDouble() }.toFloat()
        fun FloatArray.normalized(): FloatArray {
            val norm = sqrt(sumOf { (it * it).toDouble() }).toFloat().coerceAtLeast(1e-6f)
            return FloatArray(size) { this[it] / norm }
        }
        fun average(samples: List<FloatArray>): FloatArray = FloatArray(EMBEDDING_DIMENSION) { i -> samples.map { it[i] }.average().toFloat() }.normalized()
    }
}
