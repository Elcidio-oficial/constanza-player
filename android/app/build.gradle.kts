import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Carrega credenciais de assinatura de android/key.properties (fora do git).
// Se o arquivo não existir, o release usa a chave de debug (apenas sideload).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
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

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Fallback para sideload em desenvolvimento. Cria android/key.properties
                // antes de publicar na Play Store (ver android/key.properties.example).
                signingConfigs.getByName("debug")
            }
            // R8 + shrink: requer regras em proguard-rules.pro para audio_service,
            // just_audio/ExoPlayer, JAudioTagger e plugins nativos do app.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
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
