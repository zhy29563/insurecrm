plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.weapon.insurer"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.weapon.insurer"
        minSdk = 24
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        jniLibs {
            pickFirsts += setOf(
                "lib/arm64-v8a/libonnxruntime.so",
                "lib/armeabi-v7a/libonnxruntime.so",
                "lib/x86_64/libonnxruntime.so",
                "lib/x86/libonnxruntime.so",
            )
        }
    }
}

flutter {
    source = "../.."
}

// === APK 编译后自动重命名并复制到 flutter-apk/ 目录 ===
android.applicationVariants.configureEach {
    outputs.configureEach {
        val appName = "Insurer"
        val version = versionName
        val buildType = buildType.name
        (this as com.android.build.gradle.internal.api.BaseVariantOutputImpl).outputFileName = "$appName-$version-$buildType.apk"
    }
}

tasks.register("copyReleaseApk") {
    group = "build"
    description = "Copy release APK to flutter-apk directory"
    dependsOn("assembleRelease")
    doLast {
        val appName = "Insurer"
        val version = android.defaultConfig.versionName
        val srcDir = "${project.buildDir}/outputs/apk/release/"
        val dstDir = "${project.buildDir}/outputs/flutter-apk/"
        val srcName = "$appName-$version-release.apk"
        val srcFile = file("$srcDir$srcName")
        if (srcFile.exists()) {
            copy {
                from(srcFile)
                into(dstDir)
            }
            println("APK copied: $dstDir$srcName")
        } else {
            println("APK not found: $srcDir$srcName")
        }
    }
}

dependencies {
}
