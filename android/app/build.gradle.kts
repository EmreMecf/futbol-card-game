import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------
// YAYIN IMZASI
// ---------------------------------------------------------------------
// Google Play'e yuklenen paket SENIN yukleme anahtarinla imzalanmali.
// Anahtar bilgileri android/key.properties dosyasindan okunur; bu dosya
// ve .jks anahtar dosyasi .gitignore'da, depoya ASLA girmez.
// Ornek: android/key.properties.example
//
// key.properties yoksa (gelistirme) yayin derlemesi debug anahtariyla
// imzalanir; bu paket Play Store'a YUKLENEMEZ.
val anahtarDosyasi = rootProject.file("key.properties")
val anahtar = Properties().apply {
    if (anahtarDosyasi.exists()) load(FileInputStream(anahtarDosyasi))
}

android {
    namespace = "com.futbolcard.futbol_card"
    // flutter_secure_storage (jeton deposu) API 37 ile derlenmeyi sart
    // kosuyor; Flutter'in varsayilani 36. Bu satir olmadan Android
    // derlemesi (debug dahil) hic tamamlanmiyordu. (FAZ 7'de bulundu)
    // NOT: Bu sadece DERLEME surumu; desteklenen en dusuk Android
    // surumu (minSdk) degismiyor.
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Uygulama kimligi. Play Store'a ilk yuklemeden sonra DEGISTIRILEMEZ.
        applicationId = "com.futbolcard.futbol_card"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (anahtarDosyasi.exists()) {
            create("release") {
                keyAlias = anahtar["keyAlias"] as String
                keyPassword = anahtar["keyPassword"] as String
                storeFile = file(anahtar["storeFile"] as String)
                storePassword = anahtar["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (anahtarDosyasi.exists()) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "UYARI: android/key.properties yok. Yayin derlemesi DEBUG " +
                        "anahtariyla imzalaniyor; bu paket Play Store'a yuklenemez."
                )
                signingConfigs.getByName("debug")
            }
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
