package com.example.controlhorario.face

import com.example.controlhorario.database.FaceIdentificationTemplateRecord
import java.util.concurrent.atomic.AtomicInteger
import kotlin.math.sqrt
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FaceIdentificationEngineTest {
    private val scope = FaceTemplateScope(companyScopeKey = "company-test")

    @Test
    fun `clear match returns the eligible employee`() = runBlocking {
        val engine = engine(
            records = listOf(
                record(employeeId = 1, encryptedEmbedding = "best"),
                record(employeeId = 2, encryptedEmbedding = "other")
            ),
            embeddings = mapOf("best" to unit(1f), "other" to unit(0f)),
            margin = 0.10f
        )

        val result = engine.identify(unit(1f), scope, embeddingMs = 4L)

        assertTrue(result is FaceIdentificationResult.MatchConfirmed)
        assertEquals(
            1,
            (result as FaceIdentificationResult.MatchConfirmed).employee.localEmployeeId
        )
        engine.close()
    }

    @Test
    fun `candidate below current threshold returns no match`() = runBlocking {
        val engine = engine(
            records = listOf(record(employeeId = 1, encryptedEmbedding = "weak")),
            embeddings = mapOf("weak" to unit(0.70f)),
            margin = 0.10f
        )

        val result = engine.identify(unit(1f), scope, embeddingMs = 0L)

        assertTrue(result is FaceIdentificationResult.NoMatch)
        engine.close()
    }

    @Test
    fun `two close candidates above threshold return ambiguous`() = runBlocking {
        val engine = engine(
            records = listOf(
                record(employeeId = 1, encryptedEmbedding = "first"),
                record(employeeId = 2, encryptedEmbedding = "second")
            ),
            embeddings = mapOf("first" to unit(0.90f), "second" to unit(0.85f)),
            margin = 0.10f
        )

        val result = engine.identify(unit(1f), scope, embeddingMs = 0L)

        assertTrue(result is FaceIdentificationResult.MatchAmbiguous)
        engine.close()
    }

    @Test
    fun `inactive employee is excluded defensively`() = runBlocking {
        val engine = engine(
            records = listOf(
                record(
                    employeeId = 1,
                    encryptedEmbedding = "inactive",
                    employeeActive = false
                )
            ),
            embeddings = mapOf("inactive" to unit(1f)),
            margin = 0.10f
        )

        assertEquals(
            FaceIdentificationResult.NoTemplates,
            engine.identify(unit(1f), scope, embeddingMs = 0L)
        )
        engine.close()
    }

    @Test
    fun `employee with journey disabled is excluded defensively`() = runBlocking {
        val engine = engine(
            records = listOf(
                record(
                    employeeId = 1,
                    encryptedEmbedding = "disabled",
                    jornadaEnabled = false
                )
            ),
            embeddings = mapOf("disabled" to unit(1f)),
            margin = 0.10f
        )

        assertEquals(
            FaceIdentificationResult.NoTemplates,
            engine.identify(unit(1f), scope, embeddingMs = 0L)
        )
        engine.close()
    }

    @Test
    fun `company and remote branch scope exclude foreign templates`() = runBlocking {
        val restrictedScope = FaceTemplateScope(
            companyScopeKey = "company-test",
            remoteBranchId = "branch-1"
        )
        val engine = engine(
            records = listOf(
                record(
                    employeeId = 1,
                    encryptedEmbedding = "other-company",
                    remoteCompanyId = "company-other"
                ),
                record(
                    employeeId = 2,
                    encryptedEmbedding = "other-branch",
                    remoteBranchId = "branch-2"
                ),
                record(employeeId = 3, encryptedEmbedding = "eligible")
            ),
            embeddings = mapOf(
                "other-company" to unit(1f),
                "other-branch" to unit(1f),
                "eligible" to unit(1f)
            ),
            margin = 0.10f
        )

        val result = engine.identify(unit(1f), restrictedScope, embeddingMs = 0L)

        assertTrue(result is FaceIdentificationResult.MatchConfirmed)
        assertEquals(
            3,
            (result as FaceIdentificationResult.MatchConfirmed).employee.localEmployeeId
        )
        engine.close()
    }

    @Test
    fun `cache loads once and clear wipes decrypted values`() = runBlocking {
        val loads = AtomicInteger(0)
        val cache = FaceTemplateCache(
            loader = FaceTemplateLoader {
                loads.incrementAndGet()
                listOf(record(employeeId = 1, encryptedEmbedding = "face"))
            },
            decryptor = FaceTemplateDecryptor { _, _ -> unit(1f) },
            ioDispatcher = Dispatchers.Unconfined
        )

        val first = cache.load(scope)
        val second = cache.load(scope)

        assertEquals(1, loads.get())
        assertTrue(second.fromCache)
        val decrypted = first.templates.single().embedding
        cache.clear()
        assertTrue(decrypted.all { it == 0f })

        cache.load(scope)
        assertEquals(2, loads.get())
        cache.close()
    }

    @Test
    fun `cache reloads and wipes old templates when Room revision changes`() = runBlocking {
        val loads = AtomicInteger(0)
        var revision = 0L
        val cache = FaceTemplateCache(
            loader = FaceTemplateLoader {
                loads.incrementAndGet()
                listOf(record(employeeId = 1, encryptedEmbedding = "face"))
            },
            decryptor = FaceTemplateDecryptor { _, _ -> unit(1f) },
            ioDispatcher = Dispatchers.Unconfined,
            revisionProvider = { revision },
        )

        val first = cache.load(scope)
        val oldDecrypted = first.templates.single().embedding
        revision++

        val second = cache.load(scope)

        assertEquals(2, loads.get())
        assertTrue(!second.fromCache)
        assertTrue(oldDecrypted.all { it == 0f })
        cache.close()
    }

    @Test
    fun `corrupt template is skipped without losing valid templates`() = runBlocking {
        val invalid = FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION - 1) { 1f }
        val cache = FaceTemplateCache(
            loader = FaceTemplateLoader {
                listOf(
                    record(employeeId = 1, encryptedEmbedding = "throws"),
                    record(employeeId = 2, encryptedEmbedding = "invalid"),
                    record(employeeId = 3, encryptedEmbedding = "valid")
                )
            },
            decryptor = FaceTemplateDecryptor { value, _ ->
                when (value) {
                    "throws" -> error("corrupt_ciphertext")
                    "invalid" -> invalid
                    else -> unit(1f)
                }
            },
            ioDispatcher = Dispatchers.Unconfined
        )
        val engine = FaceIdentificationEngine(
            cache = cache,
            config = FaceIdentificationConfig(matchMargin = 0.10f),
            compareDispatcher = Dispatchers.Unconfined,
            performanceLogger = FaceIdentificationPerformanceLogger { }
        )

        val result = engine.identify(unit(1f), scope, embeddingMs = 0L)

        assertTrue(result is FaceIdentificationResult.MatchConfirmed)
        assertEquals(
            3,
            (result as FaceIdentificationResult.MatchConfirmed).employee.localEmployeeId
        )
        assertTrue(invalid.all { it == 0f })
        engine.close()
    }

    @Test
    fun `second concurrent identification is rejected instead of queued`() = runBlocking {
        val loadStarted = CompletableDeferred<Unit>()
        val releaseLoad = CompletableDeferred<Unit>()
        val cache = FaceTemplateCache(
            loader = FaceTemplateLoader {
                loadStarted.complete(Unit)
                releaseLoad.await()
                listOf(record(employeeId = 1, encryptedEmbedding = "face"))
            },
            decryptor = FaceTemplateDecryptor { _, _ -> unit(1f) },
            ioDispatcher = Dispatchers.Unconfined
        )
        val engine = FaceIdentificationEngine(
            cache = cache,
            config = FaceIdentificationConfig(matchMargin = 0.10f),
            compareDispatcher = Dispatchers.Unconfined,
            performanceLogger = FaceIdentificationPerformanceLogger { }
        )

        val first = async(Dispatchers.Default) {
            engine.identify(unit(1f), scope, embeddingMs = 0L)
        }
        loadStarted.await()
        val second = engine.identify(unit(1f), scope, embeddingMs = 0L)

        assertEquals(
            FaceIdentificationResult.Error(
                FaceIdentificationError.IDENTIFICATION_IN_PROGRESS
            ),
            second
        )
        releaseLoad.complete(Unit)
        assertTrue(first.await() is FaceIdentificationResult.MatchConfirmed)
        engine.close()
    }

    private fun engine(
        records: List<FaceIdentificationTemplateRecord>,
        embeddings: Map<String, FloatArray>,
        margin: Float
    ): FaceIdentificationEngine {
        val cache = FaceTemplateCache(
            loader = FaceTemplateLoader { records },
            decryptor = FaceTemplateDecryptor { value, _ -> embeddings[value]?.copyOf() },
            ioDispatcher = Dispatchers.Unconfined
        )
        return FaceIdentificationEngine(
            cache = cache,
            config = FaceIdentificationConfig(matchMargin = margin),
            compareDispatcher = Dispatchers.Unconfined,
            performanceLogger = FaceIdentificationPerformanceLogger { }
        )
    }

    private fun record(
        employeeId: Int,
        encryptedEmbedding: String,
        employeeActive: Boolean = true,
        jornadaEnabled: Boolean = true,
        biometricActive: Boolean = true,
        remoteCompanyId: String? = "company-test",
        remoteBranchId: String? = "branch-1"
    ) = FaceIdentificationTemplateRecord(
        employeeId = employeeId,
        employeeCode = employeeId.toString().padStart(6, '0'),
        employeeName = "Employee $employeeId",
        remoteCompanyId = remoteCompanyId,
        remoteBranchId = remoteBranchId,
        employeeActive = employeeActive,
        jornadaEnabled = jornadaEnabled,
        biometricActive = biometricActive,
        encryptedEmbedding = encryptedEmbedding,
        embeddingDimension = FaceEmbeddingEngine.EMBEDDING_DIMENSION
    )

    /** Unit vector whose dot product with [1, 0, ...] is [score]. */
    private fun unit(score: Float): FloatArray = FloatArray(
        FaceEmbeddingEngine.EMBEDDING_DIMENSION
    ).apply {
        this[0] = score
        this[1] = sqrt((1f - score * score).coerceAtLeast(0f))
    }
}
