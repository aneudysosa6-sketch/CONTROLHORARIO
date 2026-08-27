package com.example.controlhorario.face

import com.example.controlhorario.database.FaceIdentificationTemplateRecord
import com.example.controlhorario.repository.EmployeeFaceBiometricRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineDispatcher
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext

fun interface FaceTemplateLoader {
    suspend fun load(scope: FaceTemplateScope): List<FaceIdentificationTemplateRecord>
}

fun interface FaceTemplateDecryptor {
    fun decrypt(encryptedEmbedding: String, dimension: Int): FloatArray?
}

data class FaceIdentificationTemplate internal constructor(
    val employee: FaceIdentifiedEmployee,
    internal val embedding: FloatArray
)

data class FaceTemplateSnapshot internal constructor(
    val templates: List<FaceIdentificationTemplate>,
    val loadMs: Long,
    val fromCache: Boolean
)

/**
 * Decrypts eligible templates once per identification session/scope. Decrypted values
 * remain only in memory and are overwritten by [clear] or [close].
 */
class FaceTemplateCache(
    private val loader: FaceTemplateLoader,
    private val decryptor: FaceTemplateDecryptor,
    private val ioDispatcher: CoroutineDispatcher = Dispatchers.IO,
    private val revisionProvider: () -> Long = { FaceTemplateInvalidationBus.currentRevision },
) : AutoCloseable {
    constructor(
        repository: EmployeeFaceBiometricRepository,
        cipher: FaceEmbeddingCipher = FaceEmbeddingCipher(),
        ioDispatcher: CoroutineDispatcher = Dispatchers.IO
    ) : this(
        loader = FaceTemplateLoader { scope ->
            repository.identificationTemplates(
                remoteCompanyId = scope.companyScopeKey,
                remoteBranchId = scope.remoteBranchId
            )
        },
        decryptor = FaceTemplateDecryptor(cipher::decrypt),
        ioDispatcher = ioDispatcher
    )

    private data class CacheEntry(
        val scope: FaceTemplateScope,
        val revision: Long,
        val templates: List<FaceIdentificationTemplate>
    )

    private val loadMutex = Mutex()
    private val stateLock = Any()
    private var cached: CacheEntry? = null
    private var closed = false

    suspend fun load(scope: FaceTemplateScope): FaceTemplateSnapshot = loadMutex.withLock {
        val revision = revisionProvider()
        synchronized(stateLock) {
            check(!closed) { CACHE_CLOSED_MESSAGE }
            cached?.takeIf { it.scope == scope && it.revision == revision }?.let {
                return@withLock FaceTemplateSnapshot(it.templates, loadMs = 0L, fromCache = true)
            }
            // A scope or Room revision change invalidates old session material before IO.
            cached?.templates?.let(::wipe)
            cached = null
        }

        val startedAt = System.nanoTime()
        val records = withContext(ioDispatcher) { loader.load(scope) }
        val templates = withContext(ioDispatcher) {
            records.asSequence()
                .filter { record ->
                    record.employeeActive &&
                        record.jornadaEnabled &&
                        record.biometricActive &&
                        record.embeddingDimension == FaceEmbeddingEngine.EMBEDDING_DIMENSION &&
                        record.remoteCompanyId == scope.companyScopeKey &&
                        (scope.remoteBranchId == null ||
                            record.remoteBranchId == scope.remoteBranchId)
                }
                .mapNotNull { record ->
                    val embedding = try {
                        decryptor.decrypt(
                            record.encryptedEmbedding,
                            record.embeddingDimension
                        )
                    } catch (cancelled: CancellationException) {
                        throw cancelled
                    } catch (_: Throwable) {
                        null
                    } ?: return@mapNotNull null

                    if (
                        embedding.size != FaceEmbeddingEngine.EMBEDDING_DIMENSION ||
                        !embedding.all(Float::isFinite)
                    ) {
                        embedding.fill(0f)
                        return@mapNotNull null
                    }

                    FaceIdentificationTemplate(
                        employee = FaceIdentifiedEmployee(
                            localEmployeeId = record.employeeId,
                            employeeCode = record.employeeCode,
                            employeeName = record.employeeName
                        ),
                        embedding = embedding
                    )
                }
                .toList()
        }
        val loadMs = elapsedMillis(startedAt)

        synchronized(stateLock) {
            if (closed) {
                wipe(templates)
                throw IllegalStateException(CACHE_CLOSED_MESSAGE)
            }
            cached?.templates?.let(::wipe)
            cached = CacheEntry(scope, revision, templates)
        }
        FaceTemplateSnapshot(templates, loadMs = loadMs, fromCache = false)
    }

    /** Clears session material while keeping the cache reusable for a new session. */
    fun clear() {
        synchronized(stateLock) {
            cached?.templates?.let(::wipe)
            cached = null
        }
    }

    override fun close() {
        synchronized(stateLock) {
            cached?.templates?.let(::wipe)
            cached = null
            closed = true
        }
    }

    private fun wipe(templates: List<FaceIdentificationTemplate>) {
        templates.forEach { it.embedding.fill(0f) }
    }

    private fun elapsedMillis(startedAt: Long): Long =
        ((System.nanoTime() - startedAt) / NANOS_PER_MILLI).coerceAtLeast(0L)

    companion object {
        internal const val CACHE_CLOSED_MESSAGE = "face_template_cache_closed"
        private const val NANOS_PER_MILLI = 1_000_000L
    }
}
