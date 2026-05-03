plugins {
    id("com.android.application") apply false
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    layout.buildDirectory.set(newSubprojectBuildDir)
}

// 为缺少 namespace 的旧版插件自动设置 namespace，并统一 compileSdk
subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            if (android is com.android.build.gradle.LibraryExtension) {
                if (android.namespace == null) {
                    android.namespace = project.group.toString()
                }
                android.compileSdkVersion(36)
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// 强制兼容 AGP 8.3.1 + Kotlin 1.9.22 的依赖版本
subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            // 强制 Kotlin stdlib 版本，避免拉入 2.x 元数据不兼容
            if (requested.group == "org.jetbrains.kotlin" && requested.name.startsWith("kotlin-stdlib")) {
                useVersion("1.9.22")
                because("Kotlin stdlib must match compiler 1.9.22")
            }
            // 强制 kotlinx-coroutines 兼容版本（1.10.x 需要 Kotlin 2.x）
            if (requested.group == "org.jetbrains.kotlinx" && requested.name.startsWith("kotlinx-coroutines")) {
                useVersion("1.8.1")
                because("kotlinx-coroutines 1.10.x requires Kotlin 2.x")
            }
            // 强制 AndroidX 版本兼容 AGP 8.3.1
            if (requested.group == "androidx.browser") {
                useVersion("1.8.0")
                because("browser 1.9+ requires AGP 8.9+")
            }
            if (requested.group == "androidx.activity") {
                useVersion("1.9.3")
                because("activity 1.12+ requires AGP 8.9+")
            }
            if (requested.group == "androidx.core" && (requested.name == "core" || requested.name == "core-ktx")) {
                useVersion("1.13.1")
                because("core 1.18+ requires AGP 8.9+")
            }
            if (requested.group == "androidx.navigationevent") {
                useVersion("1.0.0-alpha02")
                because("navigationevent 1.0.2 requires AGP 8.9+")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
