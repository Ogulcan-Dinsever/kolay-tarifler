import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val propertiesFile = rootProject.file("key.properties")
    if (propertiesFile.exists()) {
        propertiesFile.inputStream().use(::load)
    }
}

fun signingValue(environmentKey: String, propertiesKey: String): String =
    System.getenv(environmentKey)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(propertiesKey)?.takeIf { it.isNotBlank() }
        ?: ""

val releaseStoreFile = signingValue("KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingValue("KEYSTORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("KEY_PASSWORD", "keyPassword")
val debugAdMobAppId = "ca-app-pub-3940256099942544~3347511713"
val releaseAdMobAppId = System.getenv("ADMOB_ANDROID_APP_ID")
    ?.takeIf { it.isNotBlank() }
    ?: "ca-app-pub-1746933154428344~9019893864"

android {
    namespace = "com.kolaytarifler.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            // Keystore bilgileri — aşağıdaki adımları takip edin:
            // 1. Terminal: keytool -genkey -v -keystore ~/kolay-tarifler-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias kolay-tarifler
            // 2. key.properties dosyasını android/ altına oluşturun (aşağıda açıklanmıştır)
            // 3. Bu bloğu key.properties'ten okuyacak şekilde güncelleyin
            if (releaseStoreFile.isNotEmpty()) storeFile = file(releaseStoreFile)
            storePassword = releaseStorePassword
            keyAlias = releaseKeyAlias
            keyPassword = releaseKeyPassword
        }
    }

    defaultConfig {
        applicationId = "com.kolaytarifler.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            manifestPlaceholders["adMobAppId"] = releaseAdMobAppId
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
            manifestPlaceholders["adMobAppId"] = debugAdMobAppId
        }
    }
}

gradle.taskGraph.whenReady {
    val needsReleaseSigning = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true) &&
            task.name.contains("bundle", ignoreCase = true)
    }
    if (needsReleaseSigning &&
        listOf(releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword)
            .any { it.isBlank() }) {
        throw GradleException(
            "Release signing is not configured. Set KEYSTORE_PATH, KEYSTORE_PASSWORD, " +
                "KEY_ALIAS and KEY_PASSWORD, or create android/key.properties from " +
                "android/key.properties.example."
        )
    }
    if (needsReleaseSigning && releaseAdMobAppId.isBlank()) {
        throw GradleException(
            "AdMob Android app ID is not configured. Set ADMOB_ANDROID_APP_ID " +
                "before building a release bundle."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
