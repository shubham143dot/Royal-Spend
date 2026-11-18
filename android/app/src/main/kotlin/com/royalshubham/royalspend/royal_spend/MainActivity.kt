package com.royalshubham.royalspend.royal_spend

import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        optimizeDisplayRefreshRate()
    }

    override fun onResume() {
        super.onResume()
        optimizeDisplayRefreshRate()
    }

    private fun optimizeDisplayRefreshRate() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val win = window ?: return
            val d = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                display
            } else {
                @Suppress("DEPRECATION")
                windowManager.defaultDisplay
            } ?: return

            val modes = d.supportedModes
            if (modes != null && modes.isNotEmpty()) {
                var maxMode = d.mode
                var maxRate = maxMode.refreshRate

                for (mode in modes) {
                    if (mode.refreshRate > maxRate) {
                        maxRate = mode.refreshRate
                        maxMode = mode
                    }
                }

                val layoutParams = win.attributes
                layoutParams.preferredDisplayModeId = maxMode.modeId
                win.attributes = layoutParams
            }
        }
    }
}
