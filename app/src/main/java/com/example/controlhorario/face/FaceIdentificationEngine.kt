package com.example.controlhorario.face

import android.util.Log
import java.util.Locale
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.withContext

data class FaceIdentificationPerformance(
    val templatesLoaded: Int,
    val loadMs: Long,
    val embeddingMs: Long,
    val compareMs: Long,
    val totalMs: Long,
    val result: FaceIdentificationStatus,
    val topScore: Float?,
    val secondScore: Float?,
    val margin: Float?
)

fun interface FaceIdentificationPerformanceLogger {
    fun log(performance: FaceIdentificationPerformance)

    data object Android : FaceIdentificationPerformanceLogger {
        override fun log(performance: FaceIdentificationPerformance) {
            Log.d(
                TAG,
                "templatesLoaded=${performance.templatesLoaded} " +
                    "loadMs=${performance.loadMs} " +
                    "embeddingMs=${performance.embeddingMs} " +
                    "compareMs=${performance.compareMs} " +
                    "totalMs=${performance.totalMs} " +
                    "result=${performance.result} " +
                    "topScore=${performance.topScore.logValue()} " +
                    "secondScore=${performance.secondScore.logValue()} " +
                    "margin=${performance.margin.logValue()}"
            )
        }

        private fun Float?.logValue(): String =
            this?.let { String.format(Locale.US, "%.5f", it) } ?: "NA"

        private const val TAG = "FACE_IDENTIFICATION_PERF"
    }
}

/**
 * Performs local 1:N matching with the exact cosine implementation used by 1:1
 * verification. A busy engine rejects a second frame instead of queuing stale work.
 */
class FaceIdentificationEngine(
    private val cache: FaceTemplateCache,
    private val config: FaceIdentificationConfig,
    private val compareDispatcher: CoroutineDispatcher = Dispatchers.Default,
    private val performanceLogger: FaceIdentificationPerformanceLogger =
        FaceIdentificationPerformanceLogger.Android
) : AutoCloseable {
    private val identificationMutex = Mutex()

    suspend fun identify(
        embedding: FloatArray,
        scope: FaceTemplateScope,
        embeddingMs: Long
    ): FaceIdentificationResult {
        val safeEmbeddingMs = embeddingMs.coerceAtLeast(0L)
        if (!identificationMutex.tryLock()) {
            return FaceIdentificationResult.Error(
                FaceIdentificationError.IDENTIFICATION_IN_PROGRESS
            ).also { result ->
                performanceLogger.log(
                    FaceIdentificationPerformance(
                        templatesLoaded = 0,
                        loadMs = 0L,
                        embeddingMs = safeEmbeddingMs,
                        compareMs = 0L,
                        totalMs = safeEmbeddingMs,
                        result = result.status,
                        topScore = null,
                        secondScore = null,
                        margin = null
                    )
                )
            }
        }

        val startedAt = System.nanoTime()
        try {
            if (
                embedding.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION ||
                !embedding.all(Float::isFinite)
            ) {
                return logAndReturn(
                    result = FaceIdentificationResult.Error(
                        FaceIdentificationError.INVALID_EMBEDDING
                    ),
                    templatesLoaded = 0,
                    loadMs = 0L,
                    embeddingMs = safeEmbeddingMs,
                    compareMs = 0L,
                    startedAt = startedAt
                )
            }

            val snapshot = try {
                cache.load(scope)
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: IllegalStateException) {
                val reason = if (error.message == FaceTemplateCache.CACHE_CLOSED_MESSAGE) {
                    FaceIdentificationError.CACHE_CLOSED
                } else {
                    FaceIdentificationError.CACHE_LOAD_FAILED
                }
                return logAndReturn(
                    result = FaceIdentificationResult.Error(reason),
                    templatesLoaded = 0,
                    loadMs = 0L,
                    embeddingMs = safeEmbeddingMs,
                    compareMs = 0L,
                    startedAt = startedAt
                )
            } catch (_: Throwable) {
                return logAndReturn(
                    result = FaceIdentificationResult.Error(
                        FaceIdentificationError.CACHE_LOAD_FAILED
                    ),
                    templatesLoaded = 0,
                    loadMs = 0L,
                    embeddingMs = safeEmbeddingMs,
                    compareMs = 0L,
                    startedAt = startedAt
                )
            }

            if (snapshot.templates.isEmpty()) {
                return logAndReturn(
                    result = FaceIdentificationResult.NoTemplates,
                    templatesLoaded = 0,
                    loadMs = snapshot.loadMs,
                    embeddingMs = safeEmbeddingMs,
                    compareMs = 0L,
                    startedAt = startedAt
                )
            }

            val compareStartedAt = System.nanoTime()
            val ranked = withContext(compareDispatcher) {
                snapshot.templates
                    .map { template ->
                        ScoredTemplate(
                            template = template,
                            score = FaceEmbeddingEngine.cosine(template.embedding, embedding)
                        )
                    }
                    .sortedByDescending(ScoredTemplate::score)
            }
            val compareMs = elapsedMillis(compareStartedAt)
            val top = ranked.first()
            val second = ranked.getOrNull(1)
            val margin = second?.let { top.score - it.score }

            val result = when {
                top.score < config.matchThreshold -> FaceIdentificationResult.NoMatch(
                    topScore = top.score,
                    secondScore = second?.score,
                    scoreMargin = margin
                )

                second != null && margin != null && margin <= config.matchMargin ->
                    FaceIdentificationResult.MatchAmbiguous(
                        topScore = top.score,
                        secondScore = second.score,
                        scoreMargin = margin
                    )

                else -> FaceIdentificationResult.MatchConfirmed(
                    employee = top.template.employee,
                    topScore = top.score,
                    secondScore = second?.score,
                    scoreMargin = margin
                )
            }
            return logAndReturn(
                result = result,
                templatesLoaded = snapshot.templates.size,
                loadMs = snapshot.loadMs,
                embeddingMs = safeEmbeddingMs,
                compareMs = compareMs,
                startedAt = startedAt
            )
        } finally {
            identificationMutex.unlock()
        }
    }

    /** Releases all decrypted templates owned by this identification session. */
    fun clearSession() = cache.clear()

    override fun close() = cache.close()

    private fun logAndReturn(
        result: FaceIdentificationResult,
        templatesLoaded: Int,
        loadMs: Long,
        embeddingMs: Long,
        compareMs: Long,
        startedAt: Long
    ): FaceIdentificationResult = result.also {
        performanceLogger.log(
            FaceIdentificationPerformance(
                templatesLoaded = templatesLoaded,
                loadMs = loadMs,
                embeddingMs = embeddingMs,
                compareMs = compareMs,
                totalMs = embeddingMs + elapsedMillis(startedAt),
                result = result.status,
                topScore = result.topScore,
                secondScore = result.secondScore,
                margin = result.scoreMargin
            )
        )
    }

    private data class ScoredTemplate(
        val template: FaceIdentificationTemplate,
        val score: Float
    )

    private fun elapsedMillis(startedAt: Long): Long =
        ((System.nanoTime() - startedAt) / NANOS_PER_MILLI).coerceAtLeast(0L)

    private companion object {
        const val NANOS_PER_MILLI = 1_000_000L
    }
}
