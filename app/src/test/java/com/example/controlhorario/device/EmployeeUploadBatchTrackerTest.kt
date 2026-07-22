package com.example.controlhorario.device

import com.example.controlhorario.database.EmployeeSyncOutboxEntity
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class EmployeeUploadBatchTrackerTest {
    @Test
    fun `handled and duplicate responses cannot become unresolved again`() {
        val first = item(id = 1L, key = "key-1")
        val second = item(id = 2L, key = "key-2")
        val tracker = EmployeeUploadBatchTracker(listOf(first, second))

        assertEquals(first, tracker.unresolvedForResponse("key-1"))
        tracker.markHandled(first.id, first.idempotencyKey)

        assertNull(tracker.unresolvedForResponse("key-1"))
        assertEquals(listOf(second), tracker.unresolvedItems())
    }

    @Test
    fun `unknown response leaves every expected item unresolved`() {
        val first = item(id = 1L, key = "key-1")
        val second = item(id = 2L, key = "key-2")
        val tracker = EmployeeUploadBatchTracker(listOf(first, second))

        assertNull(tracker.unresolvedForResponse("unknown-key"))

        assertEquals(listOf(first, second), tracker.unresolvedItems())
    }

    private fun item(id: Long, key: String) = EmployeeSyncOutboxEntity(
        id = id,
        employeeLocalId = id.toInt(),
        operation = "UPDATE",
        payloadJson = "{}",
        idempotencyKey = key,
    )
}
