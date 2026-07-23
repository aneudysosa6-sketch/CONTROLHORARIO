package com.example.controlhorario.kiosk

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.example.controlhorario.MainActivity

class BootCompletedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_LOCKED_BOOT_COMPLETED) ||
            !KioskManager(context).configuration().enabled
        ) return
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(EXTRA_BOOT_LAUNCH, true)
        )
    }

    companion object {
        const val EXTRA_BOOT_LAUNCH = "com.example.controlhorario.kiosk.BOOT_LAUNCH"
    }
}
