pluginManagement {
    val flutterSdkPath = java.util.Properties().apply {
        file("local.properties").inputStream().use { load(it) }
    }.getProperty("flutter.sdk") ?: error("flutter.sdk not set in local.properties")

    includeBuild(flutterSdkPath + "/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    val flutterSdkPath = java.util.Properties().apply {
        file("local.properties").inputStream().use { load(it) }
    }.getProperty("flutter.sdk") ?: error("flutter.sdk not set in local.properties")

    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        maven { url = uri(flutterSdkPath + "/packages/flutter_tools/gradle/maven") }
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.3.1" apply false
    id("org.jetbrains.kotlin.android") version "1.9.22" apply false
}

include(":app")
