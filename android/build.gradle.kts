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

// 兼容 AGP 8.7.0 + Kotlin 2.1.0 的依赖版本策略
subprojects {
    configurations.all {
        resolutionStrategy.eachDependency {
            // 强制 AndroidX 版本兼容
            if (requested.group == "androidx.browser") {
                useVersion("1.8.0")
                because("version pin for compatibility")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
