package com.example.insurance_manager

import android.content.Context
import android.content.SharedPreferences
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.insurance_manager/maps_config"

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        // 高德地图隐私合规 - 必须在 SDK 初始化之前调用
        initAMapPrivacy()
    }

    private fun initAMapPrivacy() {
        try {
            val clazz = Class.forName("com.amap.api.maps.MapsInitializer")
            // updatePrivacyShow(context, hasContains, hasShow)
            val updatePrivacyShow = clazz.getMethod(
                "updatePrivacyShow",
                Context::class.java,
                Boolean::class.javaPrimitiveType,
                Boolean::class.javaPrimitiveType
            )
            updatePrivacyShow.invoke(null, this, true, true)

            // updatePrivacyAgree(context, hasAgree)
            val updatePrivacyAgree = clazz.getMethod(
                "updatePrivacyAgree",
                Context::class.java,
                Boolean::class.javaPrimitiveType
            )
            updatePrivacyAgree.invoke(null, this, true)
        } catch (e: Throwable) {
            // 如果 SDK 版本不支持这些方法，静默忽略
            e.printStackTrace()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getApiKey" -> {
                    val prefs: SharedPreferences = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    // 优先读取高德地图 key，回退到旧版 Google Maps key
                    val key = prefs.getString("flutter.amap_api_key", null)
                        ?: prefs.getString("flutter.google_maps_api_key", "") ?: ""
                    result.success(key)
                }
                else -> result.notImplemented()
            }
        }
    }
}
