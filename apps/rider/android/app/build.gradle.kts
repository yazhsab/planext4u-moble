plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.planext4u.rider"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "net.planext4u.rider"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("development") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            resValue("string", "app_name", "Planext4u Rider Dev")
            manifestPlaceholders["deepLinkHost"] = "dev.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-rider-dev"
            manifestPlaceholders["deepLinkPathPrefix"] = "/rider"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Planext4u Rider Staging")
            manifestPlaceholders["deepLinkHost"] = "staging.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-rider-staging"
            manifestPlaceholders["deepLinkPathPrefix"] = "/rider"
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Planext4u Rider")
            manifestPlaceholders["deepLinkHost"] = "planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-rider"
            manifestPlaceholders["deepLinkPathPrefix"] = "/rider"
        }
    }

    buildTypes {
        release {
            // Release signing is injected by protected CI and never stored here.
        }
    }
}

flutter {
    source = "../.."
}
