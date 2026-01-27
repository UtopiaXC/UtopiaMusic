plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}



android {
    namespace = "com.utopiaxc.utopia.music"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.utopiaxc.utopia.music"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val keystorePwd = System.getenv("ANDROID_KEYSTORE_PASSWORD")
            val keyAlias = System.getenv("ANDROID_KEY_ALIAS")
            val keyPwd = System.getenv("ANDROID_KEY_PASSWORD")

            if (!keystorePath.isNullOrEmpty() && file(keystorePath).exists()) {
                storeFile = file(keystorePath)
                storePassword = keystorePwd
                this.keyAlias = keyAlias
                keyPassword = keyPwd
            }
        }
    }

    buildTypes {
        getByName("release") {
            val keystorePath = System.getenv("ANDROID_KEYSTORE_PATH")
            val isCI = System.getenv("CI") == "true"
            if (!keystorePath.isNullOrEmpty() && file(keystorePath).exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (isCI) {
                throw GradleException("CI Build Error: Keystore path not found or invalid. Check your Secrets.")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
            //isMinifyEnabled = true
        }
    }
}

flutter {
    source = "../.."
}
