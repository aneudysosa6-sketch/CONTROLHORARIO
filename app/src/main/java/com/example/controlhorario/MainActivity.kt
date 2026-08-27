package com.example.controlhorario

import android.content.Intent
import android.os.Bundle
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import com.example.controlhorario.attendance.AttendanceSyncScheduler
import com.example.controlhorario.device.DeviceSyncScheduler
import com.example.controlhorario.device.EmployeeUploadScheduler
import com.example.controlhorario.kiosk.BootCompletedReceiver
import com.example.controlhorario.kiosk.KioskController
import com.example.controlhorario.kiosk.KioskManager
import com.example.controlhorario.security.DeviceIdentityManager
import com.example.controlhorario.security.TerminalAuthorizationManager
import com.example.controlhorario.session.KioskModeManager
import com.example.controlhorario.session.SessionCoordinator
import com.example.controlhorario.ui.navigation.AppNavigation
import com.example.controlhorario.ui.theme.CONTROLHORARIOTheme

class MainActivity : FragmentActivity() {
    private val kioskController by lazy { KioskController(this) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        SessionCoordinator.init(this)
        KioskModeManager.init(this)
        TerminalAuthorizationManager.init(this)
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() = Unit
        })

        if (DeviceIdentityManager(this).deviceId != null) {
            AttendanceSyncScheduler.start(this)
            DeviceSyncScheduler.start(this)
        }
        enableEdgeToEdge()
        setContent {
            CONTROLHORARIOTheme {
                AppNavigation()
            }
        }

        if (intent.getBooleanExtra(BootCompletedReceiver.EXTRA_BOOT_LAUNCH, false) &&
            KioskManager(this).configuration().enabled
        ) {
            kioskController.enter()
        } else {
            kioskController.restore()
        }
    }

    override fun onStart() {
        super.onStart()
        if (DeviceIdentityManager(this).deviceId != null) {
            DeviceSyncScheduler.start(this)
            EmployeeUploadScheduler.enqueueImmediate(this)
        }
    }

    override fun onResume() {
        super.onResume()
        TerminalAuthorizationManager.refreshClock()
        kioskController.restore()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && KioskManager(this).configuration().enabled) {
            kioskController.immersive()
        }
    }

    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations && KioskManager(this).configuration().enabled) {
            startActivity(
                Intent(this, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            )
        }
    }
}