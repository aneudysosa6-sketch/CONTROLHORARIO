package com.example.controlhorario.ui.face

class TerminalCameraStartupSynchronizer(
    private val syncGateway: FaceTemplateSyncGateway,
) {
    suspend fun synchronizePendingEnrollments(): Boolean = syncGateway.synchronize()
}