plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.planext4u.vendor"
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
        applicationId = "net.planext4u.vendor"
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
            resValue("string", "app_name", "Planext4u Vendor Dev")
            manifestPlaceholders["deepLinkHost"] = "dev.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-vendor-dev"
            manifestPlaceholders["deepLinkPathPrefix"] = "/vendor"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Planext4u Vendor Staging")
            manifestPlaceholders["deepLinkHost"] = "staging.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-vendor-staging"
            manifestPlaceholders["deepLinkPathPrefix"] = "/vendor"
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Planext4u Vendor")
            manifestPlaceholders["deepLinkHost"] = "planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-vendor"
            manifestPlaceholders["deepLinkPathPrefix"] = "/vendor"
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
