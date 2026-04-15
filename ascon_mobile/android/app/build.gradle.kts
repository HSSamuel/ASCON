import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // Load keystore.properties
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    namespace = "com.example.ascon_mobile"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        // ✅ Enable Desugaring
        isCoreLibraryDesugaringEnabled = true
        
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    // ✅ CRITICAL FIX: Disable strict lint checks to prevent "InvalidProtocolBufferException"
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    defaultConfig {
        applicationId = "com.example.ascon_mobile"
        
        // ✅ CRITICAL FIX: Explicitly set to 26 for twilio_voice compatibility
        minSdk = 26
        
        targetSdk = 36
        
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        
        // ✅ CRITICAL FIX: Enable MultiDex for Video + Firebase
        multiDexEnabled = true
    }

    signingConfigs {
        // Only create release config if keys exist
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Add the Desugaring Library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ✅ Add MultiDex Support
    implementation("androidx.multidex:multidex:2.0.1")
    
    implementation("androidx.core:core-splashscreen:1.0.1")
}