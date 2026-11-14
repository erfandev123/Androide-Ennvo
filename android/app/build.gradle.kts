plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.erfan.ennvoapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The application id stays `com.erfan.ennvoapp`: the app keeps the
        // existing Firebase registration, the push tokens and the Play Store
        // listing of the Ennvo app.
        applicationId = "com.erfan.ennvoapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    lint {
        // The Kotlin compiler that ships with the Flutter template is not
        // compatible with the lint API in AGP 9: the release lint task fails
        // inside the Firebase plugins with a NoSuchMethodError.
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        release {
            // Signed with the debug key by default. Run
            // `node tooling/enable_release_signing.js` to switch the release
            // build over to an upload key.
            signingConfig = signingConfigs.getByName("debug")
        }
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
