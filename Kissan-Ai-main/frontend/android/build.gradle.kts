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

    // Force all Android subprojects (app + Flutter plugin libraries) to compile
    // against SDK 36+ — fixes AAR metadata errors from androidx dependencies.
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        when (androidExt) {
            is com.android.build.gradle.LibraryExtension -> androidExt.compileSdk = 36
            is com.android.build.gradle.AppExtension -> androidExt.compileSdk = 36
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
