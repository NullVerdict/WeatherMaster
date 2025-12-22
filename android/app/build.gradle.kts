import com.android.build.api.dsl.Packaging
import java.util.Properties
import java.io.FileInputStream
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystoreProps = keystorePropertiesFile.exists()
if (hasReleaseKeystoreProps) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

val devKeystoreFile: File = rootProject.file("dev-release-keystore.jks")
val devKeystoreStorePassword = "android"
val devKeystoreKeyAlias = "androiddebugkey"
val devKeystoreKeyPassword = "android"

tasks.register<Exec>("generateDevReleaseKeystore") {
    onlyIf { !hasReleaseKeystoreProps && !devKeystoreFile.exists() }

    commandLine(
        "keytool",
        "-genkeypair",
        "-v",
        "-keystore",
        devKeystoreFile.absolutePath,
        "-storepass",
        devKeystoreStorePassword,
        "-alias",
        devKeystoreKeyAlias,
        "-keypass",
        devKeystoreKeyPassword,
        "-keyalg",
        "RSA",
        "-keysize",
        "2048",
        "-validity",
        "10000",
        "-dname",
        "CN=Dev,O=Dev,C=US"
    )
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn("generateDevReleaseKeystore")
}

android {
    namespace = "com.pranshulgg.weather_master_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.pranshulgg.weather_master_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystoreProps) {
                val storeFilePath = keystoreProperties["storeFile"]?.toString()
                    ?: throw GradleException("key.properties is missing 'storeFile'")

                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"]?.toString()
                    ?: throw GradleException("key.properties is missing 'storePassword'")
                keyAlias = keystoreProperties["keyAlias"]?.toString()
                    ?: throw GradleException("key.properties is missing 'keyAlias'")
                keyPassword = keystoreProperties["keyPassword"]?.toString()
                    ?: throw GradleException("key.properties is missing 'keyPassword'")
            } else {
                storeFile = devKeystoreFile
                storePassword = devKeystoreStorePassword
                keyAlias = devKeystoreKeyAlias
                keyPassword = devKeystoreKeyPassword
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.work:work-runtime-ktx:2.9.0")
    implementation("androidx.glance:glance-appwidget:1.0.0-alpha05")
    implementation("com.google.android.material:material:1.12.0")
}