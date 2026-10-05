package com.example.Friday_assistant

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "friday_automation"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "launchApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName == null) {
                        result.error("ARGUMENT_ERROR", "Missing 'package' argument", null)
                        return@setMethodCallHandler
                    }
                    val success = launchApp(packageName)
                    result.success(success)
                }
                "canLaunchApp" -> {
                    val packageName = call.argument<String>("package")
                    if (packageName == null) {
                        result.error("ARGUMENT_ERROR", "Missing 'package' argument", null)
                        return@setMethodCallHandler
                    }
                    result.success(canLaunchApp(packageName))
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun launchApp(packageName: String): Boolean {
        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName)
            if (intent != null) {
                startActivity(intent)
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun canLaunchApp(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }
}
