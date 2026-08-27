package com.example.controlhorario.face

import com.example.controlhorario.model.Employee
import java.util.ArrayDeque
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class InitialFaceEnrollmentRepositoryTest {
    private val scope = InitialFaceEnrollmentScope("device-1", "company-1", "branch-1")

    @Test fun `public code is exactly six numeric digits and zero is rejected`() {
        assertFalse(InitialFaceEmployeeCodePolicy.isValid("00000"))
        assertFalse(InitialFaceEmployeeCodePolicy.isValid("000008 "))
        assertFalse(InitialFaceEmployeeCodePolicy.isValid("A00008"))
        assertFalse(InitialFaceEmployeeCodePolicy.isValid("000000"))
        assertTrue(InitialFaceEmployeeCodePolicy.isValid("000008"))
        assertTrue(InitialFaceEmployeeCodePolicy.isValid("48575"))
        assertEquals("048575", InitialFaceEmployeeCodePolicy.normalizeOrNull("48575"))
        assertEquals(
            listOf("000008", "00008"),
            InitialFaceEmployeeCodePolicy.lookupCandidates("000008")
        )
    }

    @Test fun `only definitive initial upload rejection invalidates local enrollment`() {
        assertTrue(InitialFaceUploadRejectionPolicy.isDefinitive("EMPLOYEE_INACTIVE"))
        assertTrue(InitialFaceUploadRejectionPolicy.isDefinitive("BRANCH_MISMATCH"))
        assertTrue(InitialFaceUploadRejectionPolicy.isDefinitive("JOURNEY_DISABLED"))
        assertFalse(InitialFaceUploadRejectionPolicy.isDefinitive("DATABASE_ERROR"))
        assertFalse(InitialFaceUploadRejectionPolicy.isDefinitive(null))
        assertEquals(
            "REMOTE_REJECTED_EMPLOYEE_INACTIVE",
            InitialFaceUploadRejectionPolicy.safeAuditOutcome("EMPLOYEE_INACTIVE")
        )
    }

    @Test fun `six digit public code resolves canonical legacy code without using pin`() = runBlocking {
        val fixture = fixture(employees = listOf(employee(code = "00008")))

        val result = fixture.repository.check("000008")

        assertTrue(result is InitialFaceEligibility.Allowed)
        assertEquals("000008", (result as InitialFaceEligibility.Allowed).employee.employeeCode)
        assertEquals(listOf("000008"), fixture.remoteCodes)
    }

    @Test fun `five digit historical input is processed as canonical six digit code`() = runBlocking {
        val fixture = fixture(employees = listOf(employee(id = 48_575, code = "48575")))

        val result = fixture.repository.check("48575")

        assertTrue(result is InitialFaceEligibility.Allowed)
        assertEquals("048575", (result as InitialFaceEligibility.Allowed).employee.employeeCode)
        assertEquals(listOf("048575"), fixture.remoteCodes)
    }

    @Test fun `exact and legacy employees colliding are rejected as ambiguous`() = runBlocking {
        val fixture = fixture(
            employees = listOf(
                employee(id = 8, code = "00008"),
                employee(id = 9, code = "000008", remoteId = "remote-9")
            )
        )

        assertDenied(
            InitialFaceEnrollmentDenial.EMPLOYEE_CODE_AMBIGUOUS,
            fixture.repository.check("000008")
        )
        assertTrue(fixture.remoteCodes.isEmpty())
    }

    @Test fun `remote code reassignment cannot enroll a different employee`() = runBlocking {
        var current = employee(remoteId = "remote-original")
        val repository = InitialFaceEnrollmentRepository(
            employees = object : InitialFaceEmployeeSource {
                override suspend fun findByExactEmployeeCode(employeeCode: String) =
                    current.takeIf { it.employeeCode == employeeCode }

                override suspend fun findByLocalId(employeeLocalId: Int) =
                    current.takeIf { it.id == employeeLocalId }
            },
            localFaces = InitialFaceLocalFaceSource { false },
            remote = InitialFaceRemoteGateway {
                current = current.copy(remoteId = "remote-reassigned")
                InitialFaceRemoteState.Absent
            },
            scopes = InitialFaceScopeSource { scope },
            persistence = InitialFacePersistence { _, _, _ ->
                InitialFacePersistenceResult.Saved(1)
            },
            scheduler = InitialFaceSyncScheduler {},
        )

        assertDenied(
            InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED,
            repository.check("000008"),
        )
    }

    @Test fun `remote reassignment during commit cannot enroll a different employee`() = runBlocking {
        var current = employee(remoteId = "remote-original")
        var remoteInspections = 0
        var persistenceCalls = 0
        val repository = InitialFaceEnrollmentRepository(
            employees = object : InitialFaceEmployeeSource {
                override suspend fun findByExactEmployeeCode(employeeCode: String) =
                    current.takeIf { it.employeeCode == employeeCode }

                override suspend fun findByLocalId(employeeLocalId: Int) =
                    current.takeIf { it.id == employeeLocalId }
            },
            localFaces = InitialFaceLocalFaceSource { false },
            remote = InitialFaceRemoteGateway {
                remoteInspections++
                if (remoteInspections == 2) {
                    current = current.copy(remoteId = "remote-reassigned")
                }
                InitialFaceRemoteState.Absent
            },
            scopes = InitialFaceScopeSource { scope },
            persistence = InitialFacePersistence { _, _, _ ->
                persistenceCalls++
                InitialFacePersistenceResult.Saved(1)
            },
            scheduler = InitialFaceSyncScheduler {},
        )
        val permit = (repository.check("000008") as InitialFaceEligibility.Allowed).permit

        assertCommitDenied(
            InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED,
            repository.commit(
                permit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION),
            ),
        )
        assertEquals(2, remoteInspections)
        assertEquals(0, persistenceCalls)
    }

    @Test fun `local face blocks enrollment before remote request`() = runBlocking {
        val fixture = fixture(localFace = true)

        assertDenied(
            InitialFaceEnrollmentDenial.LOCAL_FACE_ALREADY_REGISTERED,
            fixture.repository.check("000008")
        )
        assertTrue(fixture.remoteCodes.isEmpty())
    }

    @Test fun `remote valid or invalid non null face fails closed`() = runBlocking {
        val valid = fixture(remoteStates = listOf(InitialFaceRemoteState.Present(true, 128)))
        assertDenied(
            InitialFaceEnrollmentDenial.REMOTE_FACE_ALREADY_REGISTERED,
            valid.repository.check("000008")
        )

        val invalid = fixture(remoteStates = listOf(InitialFaceRemoteState.Present(false, 17)))
        assertDenied(
            InitialFaceEnrollmentDenial.REMOTE_FACE_INVALID,
            invalid.repository.check("000008")
        )
    }

    @Test fun `offline allows only employee with prior remote synchronization`() = runBlocking {
        val synced = fixture(remoteStates = listOf(InitialFaceRemoteState.Offline))
        val allowed = synced.repository.check("000008")
        assertTrue(allowed is InitialFaceEligibility.Allowed)
        assertEquals(
            InitialFaceValidationMode.OFFLINE_CACHED,
            (allowed as InitialFaceEligibility.Allowed).permit.validationMode
        )

        val unsynced = fixture(
            employees = listOf(
                employee().copy(remoteId = null, remoteCompanyId = null, lastSyncedAt = null)
            ),
            remoteStates = listOf(InitialFaceRemoteState.Offline)
        )
        assertDenied(
            InitialFaceEnrollmentDenial.EMPLOYEE_NOT_SYNCED,
            unsynced.repository.check("000008")
        )
    }

    @Test fun `inactive wrong scope and journey disabled employees are rejected`() = runBlocking {
        val cases = listOf(
            employee().copy(isActive = false) to InitialFaceEnrollmentDenial.EMPLOYEE_INACTIVE,
            employee().copy(employmentStatus = "desvinculado") to InitialFaceEnrollmentDenial.EMPLOYEE_INACTIVE,
            employee().copy(remoteCompanyId = "other") to InitialFaceEnrollmentDenial.COMPANY_MISMATCH,
            employee().copy(remoteBranchId = "other") to InitialFaceEnrollmentDenial.BRANCH_MISMATCH,
            employee().copy(jornadaEnabled = false) to InitialFaceEnrollmentDenial.JOURNEY_DISABLED
        )
        cases.forEach { (employee, expected) ->
            val fixture = fixture(employees = listOf(employee))
            assertDenied(expected, fixture.repository.check("000008"))
            assertTrue(fixture.remoteCodes.isEmpty())
        }
    }

    @Test fun `successful commit persists once schedules once and audits only safe fields`() = runBlocking {
        val fixture = fixture(
            remoteStates = listOf(InitialFaceRemoteState.Absent, InitialFaceRemoteState.Absent)
        )
        val eligibility = fixture.repository.check("000008") as InitialFaceEligibility.Allowed
        assertTrue(fixture.audits.isEmpty())
        val embedding = FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION) { 0.01f }

        val result = fixture.repository.commit(eligibility.permit, embedding)

        assertTrue(result is InitialFaceCommitResult.Saved)
        assertEquals(1, fixture.persistenceCalls)
        assertEquals(1, fixture.scheduleCalls)
        assertTrue(embedding.all { it == 0f })
        val audit = fixture.audits.single()
        assertEquals(InitialFaceEnrollmentAudit.EVENT_NAME, audit.eventName)
        assertEquals("device-1", audit.deviceId)
        assertEquals("EMPLOYEE_SELF_SERVICE", audit.responsibleUser)
        assertEquals("000008", audit.employeeCode)
        val description = audit.safeDescription().lowercase()
        assertFalse("embedding" in description)
        assertFalse("pin" in description)
        assertFalse("photo" in description)
        assertFalse("employee name" in description)

        assertCommitDenied(
            InitialFaceEnrollmentDenial.PERMIT_ALREADY_USED,
            fixture.repository.commit(
                eligibility.permit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
        )
        assertEquals(1, fixture.persistenceCalls)
        assertEquals(1, fixture.scheduleCalls)
    }

    @Test fun `invalid embedding does not write and valid retry can consume permit`() = runBlocking {
        val fixture = fixture(
            remoteStates = listOf(InitialFaceRemoteState.Absent, InitialFaceRemoteState.Absent)
        )
        val permit = (fixture.repository.check("000008") as InitialFaceEligibility.Allowed).permit

        assertCommitDenied(
            InitialFaceEnrollmentDenial.INVALID_EMBEDDING,
            fixture.repository.commit(permit, FloatArray(127))
        )
        assertEquals(0, fixture.persistenceCalls)
        assertTrue(
            fixture.repository.commit(
                permit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            ) is InitialFaceCommitResult.Saved
        )
    }

    @Test fun `local TOCTOU and remote race cannot replace an existing face`() = runBlocking {
        val localRace = fixture(
            remoteStates = listOf(InitialFaceRemoteState.Absent, InitialFaceRemoteState.Absent)
        )
        val localPermit =
            (localRace.repository.check("000008") as InitialFaceEligibility.Allowed).permit
        localRace.localFace = true
        assertCommitDenied(
            InitialFaceEnrollmentDenial.LOCAL_FACE_ALREADY_REGISTERED,
            localRace.repository.commit(
                localPermit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
        )
        assertEquals(0, localRace.persistenceCalls)

        val remoteRace = fixture(
            remoteStates = listOf(
                InitialFaceRemoteState.Absent,
                InitialFaceRemoteState.Present(true, 128)
            )
        )
        val remotePermit =
            (remoteRace.repository.check("000008") as InitialFaceEligibility.Allowed).permit
        assertCommitDenied(
            InitialFaceEnrollmentDenial.REMOTE_FACE_ALREADY_REGISTERED,
            remoteRace.repository.commit(
                remotePermit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
        )
        assertEquals(0, remoteRace.persistenceCalls)
    }

    @Test fun `permit is bound to device company and branch scope`() = runBlocking {
        val fixture = fixture(
            remoteStates = listOf(InitialFaceRemoteState.Absent)
        )
        val permit = (fixture.repository.check("000008") as InitialFaceEligibility.Allowed).permit
        fixture.currentScope = scope.copy(deviceId = "device-2")

        assertCommitDenied(
            InitialFaceEnrollmentDenial.EMPLOYEE_CHANGED,
            fixture.repository.commit(
                permit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
        )
        assertEquals(0, fixture.persistenceCalls)
    }

    @Test fun `database insert conflict is reported and never scheduled`() = runBlocking {
        val fixture = fixture(
            remoteStates = listOf(InitialFaceRemoteState.Absent, InitialFaceRemoteState.Absent),
            persistenceResult = InitialFacePersistenceResult.AlreadyExists
        )
        val permit = (fixture.repository.check("000008") as InitialFaceEligibility.Allowed).permit

        assertCommitDenied(
            InitialFaceEnrollmentDenial.CONCURRENT_ENROLLMENT,
            fixture.repository.commit(
                permit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
        )
        assertEquals(1, fixture.persistenceCalls)
        assertEquals(0, fixture.scheduleCalls)
    }

    @Test fun `expired permit cannot be committed`() = runBlocking {
        var now = 1_000L
        val fixture = fixture(
            remoteStates = listOf(InitialFaceRemoteState.Absent),
            clock = { now },
            permitTtlMillis = 10L
        )
        val permit = (fixture.repository.check("000008") as InitialFaceEligibility.Allowed).permit
        now = 1_011L

        assertCommitDenied(
            InitialFaceEnrollmentDenial.PERMIT_EXPIRED,
            fixture.repository.commit(
                permit,
                FloatArray(FaceEmbeddingEngine.EMBEDDING_DIMENSION)
            )
        )
        assertTrue(fixture.remoteCodes.size == 1)
    }

    private fun fixture(
        employees: List<Employee> = listOf(employee()),
        localFace: Boolean = false,
        remoteStates: List<InitialFaceRemoteState> = listOf(InitialFaceRemoteState.Absent),
        persistenceResult: InitialFacePersistenceResult = InitialFacePersistenceResult.Saved(41),
        clock: () -> Long = { 1_000L },
        permitTtlMillis: Long = 60_000L
    ): Fixture {
        val fixture = Fixture(employees, localFace, remoteStates, persistenceResult)
        fixture.repository = InitialFaceEnrollmentRepository(
            employees = fixture.employeeSource,
            localFaces = InitialFaceLocalFaceSource { fixture.localFace },
            remote = InitialFaceRemoteGateway { employeeCode ->
                fixture.remoteCodes += employeeCode
                if (fixture.remoteStates.size > 1) fixture.remoteStates.removeFirst()
                else fixture.remoteStates.first()
            },
            scopes = InitialFaceScopeSource { fixture.currentScope },
            persistence = InitialFacePersistence { _, embedding, audit ->
                fixture.persistenceCalls++
                fixture.persistedEmbedding = embedding.copyOf()
                fixture.audits += audit
                fixture.persistenceResult
            },
            scheduler = InitialFaceSyncScheduler { fixture.scheduleCalls++ },
            clockMillis = clock,
            isoTimestamp = { "2026-07-21T12:00:00Z" },
            permitTtlMillis = permitTtlMillis
        )
        return fixture
    }

    private fun employee(
        id: Int = 8,
        code: String = "00008",
        remoteId: String = "remote-8"
    ) = Employee(
        id = id,
        employeeCode = code,
        pin = "different-secret",
        nombre = "Sensitive Employee Name",
        isActive = true,
        employmentStatus = "activo",
        jornadaEnabled = true,
        remoteId = remoteId,
        remoteCompanyId = "company-1",
        remoteBranchId = "branch-1",
        remoteUpdatedAt = "2026-07-21T11:00:00Z",
        lastSyncedAt = 1L,
        syncStatus = "SYNCED"
    )

    private fun assertDenied(
        expected: InitialFaceEnrollmentDenial,
        actual: InitialFaceEligibility
    ) {
        assertTrue(actual is InitialFaceEligibility.Denied)
        assertEquals(expected, (actual as InitialFaceEligibility.Denied).reason)
    }

    private fun assertCommitDenied(
        expected: InitialFaceEnrollmentDenial,
        actual: InitialFaceCommitResult
    ) {
        assertTrue(actual is InitialFaceCommitResult.Denied)
        assertEquals(expected, (actual as InitialFaceCommitResult.Denied).reason)
    }

    private class Fixture(
        employees: List<Employee>,
        var localFace: Boolean,
        remoteStates: List<InitialFaceRemoteState>,
        val persistenceResult: InitialFacePersistenceResult
    ) {
        val byCode = employees.associateBy(Employee::employeeCode)
        val byId = employees.associateBy(Employee::id).toMutableMap()
        val remoteStates = ArrayDeque(remoteStates)
        val remoteCodes = mutableListOf<String>()
        val audits = mutableListOf<InitialFaceEnrollmentAudit>()
        var persistedEmbedding: FloatArray? = null
        var persistenceCalls = 0
        var scheduleCalls = 0
        var currentScope = InitialFaceEnrollmentScope("device-1", "company-1", "branch-1")
        lateinit var repository: InitialFaceEnrollmentRepository
        val employeeSource = object : InitialFaceEmployeeSource {
            override suspend fun findByExactEmployeeCode(employeeCode: String): Employee? =
                byCode[employeeCode]

            override suspend fun findByLocalId(employeeLocalId: Int): Employee? =
                byId[employeeLocalId]
        }
    }
}
