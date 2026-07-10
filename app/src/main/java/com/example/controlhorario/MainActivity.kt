package com.example.controlhorario

import android.os.Bundle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.fragment.app.FragmentActivity
import androidx.navigation.compose.rememberNavController
import com.example.controlhorario.session.UserSessionManager
import com.example.controlhorario.ui.navigation.AppNavigation
import com.example.controlhorario.ui.theme.CONTROLHORARIOTheme

class MainActivity : FragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        UserSessionManager.init(this)
        enableEdgeToEdge()

        setContent {
            CONTROLHORARIOTheme {
                val navController = rememberNavController()
                AppNavigation(navController)
            }
        }
    }
}
