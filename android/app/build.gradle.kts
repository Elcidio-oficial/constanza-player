plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.constanza.constanza_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    defaultConfig {
        applicationId = "com.constanza.constanza_player"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Usa a chave de debug para permitir instalação via sideload durante o desenvolvimento.
            // Para publicar na Play Store, substitua por um signingConfig com keystore próprio.
            signingConfig = signingConfigs.getByName("debug")
            // Minificação desativada para preservar as classes do audio_service/just_audio
            // que são necessárias para notificação e tela de bloqueio.
            // As regras ProGuard em proguard-rules.pro ficam prontas para quando a
            // minificação for reativada antes de publicar na Play Store.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Palette API para extração de cores do artwork na notificação
    implementation("androidx.palette:palette-ktx:1.0.0")
    // JAudioTagger para edição de tags ID3/Vorbis nos arquivos de áudio
    implementation("net.jthink:jaudiotagger:3.0.1")
}

flutter {
    source = "../.."
}