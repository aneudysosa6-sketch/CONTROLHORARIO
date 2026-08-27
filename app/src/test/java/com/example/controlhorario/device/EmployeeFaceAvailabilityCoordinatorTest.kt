package com.example.controlhorario.device

import com.example.controlhorario.model.Employee
import java.io.IOException
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class EmployeeFaceAvailabilityCoordinatorTest {
    private val employee = Employee(id = 7, employeeCode = "000007")

    @Test fun `missing local and remote 128 becomes available without another code entry`() = runBlocking {
        var localFace = false
        val coordinator = EmployeeFaceAvailabilityCoordinator(
            faceExists = { localFace },
            targetedSync = TargetedEmployeeSyncGateway { localFace = true }
        )
        assertEquals(FaceAvailabilityResult.SYNCED, coordinator.ensure(employee))
        assertTrue(localFace)
        assertEquals("000007", employee.employeeCode)
    }

    @Test fun `remote null never removes valid local face`() = runBlocking {
        var localFace = true
        var syncCalls = 0
        val coordinator = EmployeeFaceAvailabilityCoordinator(
            faceExists = { localFace },
            targetedSync = TargetedEmployeeSyncGateway { syncCalls++; localFace = false }
        )
        assertEquals(FaceAvailabilityResult.LOCAL, coordinator.ensure(employee))
        assertTrue(localFace)
        assertEquals(0, syncCalls)
        assertFalse(FacePersistencePolicy.shouldStore(null, localFaceExists = true))
    }

    @Test fun `concurrent requests perform one targeted sync`() = runBlocking {
        val localFace = AtomicBoolean(false)
        val calls = AtomicInteger(0)
        val inFlight = AtomicInteger(0)
        val maxInFlight = AtomicInteger(0)
        val coordinator = EmployeeFaceAvailabilityCoordinator(
            faceExists = { localFace.get() },
            targetedSync = TargetedEmployeeSyncGateway {
                calls.incrementAndGet()
                val current = inFlight.incrementAndGet()
                maxInFlight.updateAndGet { maxOf(it, current) }
                delay(25)
                localFace.set(true)
                inFlight.decrementAndGet()
            }
        )
        val first = async { coordinator.ensure(employee) }
        val second = async { coordinator.ensure(employee) }
        assertEquals(FaceAvailabilityResult.SYNCED, first.await())
        assertEquals(FaceAvailabilityResult.LOCAL, second.await())
        assertEquals(1, calls.get())
        assertEquals(1, maxInFlight.get())
    }

    @Test fun `network failure is propagated for controlled retry`() = runBlocking {
        val coordinator = EmployeeFaceAvailabilityCoordinator(
            faceExists = { false },
            targetedSync = TargetedEmployeeSyncGateway { throw IOException("offline") }
        )
        var error: Throwable? = null
        try { coordinator.ensure(employee) } catch (caught: Throwable) { error = caught }
        assertTrue(error is IOException)
        assertEquals("000007", employee.employeeCode)
    }

    @Test fun `valid remote face stores only when local is missing`() {
        assertTrue(FacePersistencePolicy.shouldStore(FloatArray(128) { 0.01f }, localFaceExists = false))
        assertFalse(FacePersistencePolicy.shouldStore(FloatArray(128), localFaceExists = true))
        assertFalse(FacePersistencePolicy.shouldStore(FloatArray(127), localFaceExists = false))
    }
}
