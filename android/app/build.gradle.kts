plugins {
    id("com.android.application")

    // O Flutter Gradle Plugin deve permanecer depois
    // do plugin do Android.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.finanse.finanse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necessário para as notificações programadas.
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.finanse.finanse"

        // O local_auth 3 exige Android SDK 24 ou superior.
        minSdk = 24

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    buildTypes {
        release {
            // A assinatura definitiva será configurada
            // na etapa de lançamento.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget =
            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring(
        "com.android.tools:desugar_jdk_libs:2.1.4",
    )
}

flutter {
    source = "../.."
}