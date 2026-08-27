package com.example.controlhorario.kiosk

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context

class DeviceOwnerHelper(context: Context) {
    private val appContext = context.applicationContext
    private val policyManager = appContext.getSystemService(DevicePolicyManager::class.java)
    val receiver = ComponentName(appContext, DevicePolicyReceiver::class.java)

    fun isDeviceOwner(): Boolean = policyManager.isDeviceOwnerApp(appContext.packageName)

    fun prepareLockTaskPackages(): Boolean {
        if (!isDeviceOwner()) return false
        policyManager.setLockTaskPackages(receiver, arrayOf(appContext.packageName))
        return policyManager.isLockTaskPermitted(appContext.packageName)
    }

    fun clearLockTaskPackages() {
        if (isDeviceOwner()) policyManager.setLockTaskPackages(receiver, emptyArray())
    }
}
