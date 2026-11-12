import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing with the permanent NexusTrade key.
// Source 1: android/key.properties (never committed) with storePassword,
//           keyPassword, keyAlias, storeFile.
// Source 2 (CI): env NEXUS_KEYSTORE_PATH, NEXUS_STORE_PASSWORD,
//           NEXUS_KEY_PASSWORD, NEXUS_KEY_ALIAS.
// Without a key a release build FAILS, unless NEXUS_ALLOW_DEBUG_SIGNING=1
// is set explicitly (test builds only - such APKs cannot update releases).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} else if (System.getenv("NEXUS_KEYSTORE_PATH") != null) {
    keystoreProperties["storeFile"] = System.getenv("NEXUS_KEYSTORE_PATH")
    keystoreProperties["storePassword"] = System.getenv("NEXUS_STORE_PASSWORD") ?: ""
    keystoreProperties["keyPassword"] = System.getenv("NEXUS_KEY_PASSWORD") ?: ""
    keystoreProperties["keyAlias"] = System.getenv("NEXUS_KEY_ALIAS") ?: "nexustrade"
}
val hasReleaseKey = keystoreProperties.containsKey("storeFile")
val allowDebugSigning = System.getenv("NEXUS_ALLOW_DEBUG_SIGNING") == "1"

android {
    namespace = "uz.nexustrade.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications (scheduled reminders).
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "uz.nexustrade.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = when {
                hasReleaseKey -> signingConfigs.getByName("release")
                allowDebugSigning -> signingConfigs.getByName("debug")
                else -> null
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseTask = allTasks.any { it.name.contains("Release") && it.name.startsWith("assemble") }
    if (releaseTask && !hasReleaseKey && !allowDebugSigning) {
        throw GradleException(
            "NexusTrade: release signing key not configured. Create android/key.properties " +
                "(see docs/SIGNING.md) or set NEXUS_ALLOW_DEBUG_SIGNING=1 for a test build."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
