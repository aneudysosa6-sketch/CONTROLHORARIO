package com.example.controlhorario.device

import com.example.controlhorario.database.EmployeeSyncOutboxEntity

/** Tracks which rows in one upload batch still need a terminal outbox transition. */
internal class EmployeeUploadBatchTracker(items: List<EmployeeSyncOutboxEntity>) {
    private val itemsById = items.associateBy(EmployeeSyncOutboxEntity::id)
    private val idsByIdempotencyKey = items.associate { it.idempotencyKey to it.id }
    private val unresolvedIds = items.mapTo(linkedSetOf(), EmployeeSyncOutboxEntity::id)

    init {
        require(itemsById.size == items.size) { "EMPLOYEE_UPLOAD_DUPLICATE_OUTBOX_ID" }
        require(idsByIdempotencyKey.size == items.size) {
            "EMPLOYEE_UPLOAD_DUPLICATE_IDEMPOTENCY_KEY"
        }
    }

    fun unresolvedForResponse(idempotencyKey: String): EmployeeSyncOutboxEntity? {
        val id = idsByIdempotencyKey[idempotencyKey] ?: return null
        return itemsById[id]?.takeIf { id in unresolvedIds }
    }

    fun markHandled(id: Long, idempotencyKey: String) {
        val expectedId = idsByIdempotencyKey[idempotencyKey]
        require(expectedId == id && itemsById.containsKey(id)) {
            "EMPLOYEE_UPLOAD_BATCH_ITEM_MISMATCH"
        }
        unresolvedIds.remove(id)
    }

    fun unresolvedItems(): List<EmployeeSyncOutboxEntity> =
        unresolvedIds.mapNotNull(itemsById::get)
}
