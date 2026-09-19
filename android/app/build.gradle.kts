import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Chave de assinatura própria, quando existir. Sem ela o Gradle cai na
// chave de debug, que é GERADA DE NOVO a cada máquina/runner — e aí o
// Android recusa atualizar por cima, exigindo desinstalar antes.
val propsAssinatura = Properties().apply {
    val arquivo = rootProject.file("key.properties")
    if (arquivo.exists()) arquivo.inputStream().use { load(it) }
}
val temChavePropria = propsAssinatura.getProperty("storeFile") != null

android {
    namespace = "com.leonardoleote.estoque_casa"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Exigido pelo flutter_local_notifications (usa java.time no desugar).
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.leonardoleote.estoque_casa"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (temChavePropria) {
            create("release") {
                storeFile = file(propsAssinatura.getProperty("storeFile"))
                storePassword = propsAssinatura.getProperty("storePassword")
                keyAlias = propsAssinatura.getProperty("keyAlias")
                keyPassword = propsAssinatura.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (temChavePropria) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
