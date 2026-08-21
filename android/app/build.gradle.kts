import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")

    // O Flutter Gradle Plugin deve permanecer depois
    // do plugin do Android.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(
        FileInputStream(keystorePropertiesFile),
    )
}

val releaseSigningKeys = listOf(
    "keyAlias",
    "keyPassword",
    "storeFile",
    "storePassword",
)

val releaseSigningConfigured =
    keystorePropertiesFile.exists() &&
        releaseSigningKeys.all { key ->
            !keystoreProperties.getProperty(key).isNullOrBlank()
        }

if (keystorePropertiesFile.exists() && !releaseSigningConfigured) {
    throw GradleException(
        "android/key.properties existe, mas a configuração de assinatura está incompleta.",
    )
}

val releaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

if (releaseTaskRequested && !releaseSigningConfigured) {
    throw GradleException(
        "A assinatura release não está configurada. Crie android/key.properties antes de gerar uma versão de produção.",
    )
}

android {
    namespace = "com.finanse.finanse"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Necessario para as notificacoes programadas.
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.finanse.finanse"

        minSdk = 24

        targetSdk = flutter.targetSdkVersion

        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                keyAlias =
                    keystoreProperties.getProperty("keyAlias")

                keyPassword =
                    keystoreProperties.getProperty("keyPassword")

                storeFile =
                    file(keystoreProperties.getProperty("storeFile"))

                storePassword =
                    keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig =
                    signingConfigs.getByName("release")
            }
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
