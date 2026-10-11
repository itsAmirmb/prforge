allprojects {
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://storage.flutter-io.cn/download.flutter.io") }
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

// Some plugins (e.g. file_picker) are still compiled against an older
// compileSdk than androidx.lifecycle requires (36). Raise it for plugin
// libraries only. Must be registered before evaluationDependsOn below.
subprojects {
    if (!state.executed) {
        afterEvaluate {
            if (plugins.hasPlugin("com.android.library")) {
                extensions.findByName("android")?.withGroovyBuilder {
                    "compileSdkVersion"(36)
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
