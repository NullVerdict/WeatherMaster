import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

subprojects {
    val flutterCompileSdkVersion = (findProperty("flutter.compileSdkVersion") as String?)?.toIntOrNull()
    val flutterTargetSdkVersion = (findProperty("flutter.targetSdkVersion") as String?)?.toIntOrNull()

    plugins.withId("com.android.application") {
        extensions.configure<ApplicationExtension> {
            flutterCompileSdkVersion?.let { compileSdk = it }
            defaultConfig {
                flutterTargetSdkVersion?.let { targetSdk = it }
            }
        }
    }

    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            flutterCompileSdkVersion?.let { compileSdk = it }
            defaultConfig {
                flutterTargetSdkVersion?.let { targetSdk = it }
            }
        }
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
