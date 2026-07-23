package com.example.controlhorario.kiosk

import android.app.Activity
import android.app.ActivityManager
import android.os.Build
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat

class KioskController(private val activity: Activity) {
    private val owner = DeviceOwnerHelper(activity)

    fun enter() {
        immersive()
        owner.prepareLockTaskPackages()
        if (!isInLockTask()) runCatching { activity.startLockTask() }
    }

    fun restore() {
        if (KioskManager(activity).configuration().enabled) enter()
    }

    fun exit() {
        runCatching { activity.stopLockTask() }
        owner.clearLockTaskPackages()
        WindowCompat.getInsetsController(activity.window, activity.window.decorView).show(
            WindowInsetsCompat.Type.systemBars()
        )
    }

    fun immersive() {
        WindowCompat.setDecorFitsSystemWindows(activity.window, false)
        activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity.window.insetsController?.apply {
                hide(WindowInsets.Type.systemBars())
                systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            WindowInsetsControllerCompat(activity.window, activity.window.decorView).apply {
                hide(WindowInsetsCompat.Type.systemBars())
                systemBarsBehavior = WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        }
    }

    private fun isInLockTask(): Boolean {
        val manager = activity.getSystemService(ActivityManager::class.java)
        return manager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
    }
}
