allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    // Force every Android plugin subproject to compile against API 36+.
    // Some plugins (e.g. file_picker) hardcode an older compileSdk (34) inside
    // their own android {} block, but flutter_plugin_android_lifecycle now
    // requires consumers to compile against Android API 36+. This override must
    // run in afterEvaluate so it applies AFTER the plugin sets its own value.
    // Registering afterEvaluate here (before evaluationDependsOn below triggers
    // evaluation) avoids the "project already evaluated" error. Overriding
    // compileSdk only affects compile-time APIs; targetSdk/minSdk are left
    // untouched, so runtime behavior and device support are unchanged.
    project.afterEvaluate {
        extensions.findByName("android")?.let { ext ->
            (ext as com.android.build.gradle.BaseExtension).compileSdkVersion(36)
        }
    }

    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
