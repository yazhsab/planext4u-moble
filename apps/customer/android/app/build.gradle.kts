plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "net.planext4u.customer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "net.planext4u.customer"
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
            resValue("string", "app_name", "Planext4u Customer Dev")
            manifestPlaceholders["deepLinkHost"] = "dev.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-customer-dev"
            manifestPlaceholders["deepLinkPathPrefix"] = "/app"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Planext4u Customer Staging")
            manifestPlaceholders["deepLinkHost"] = "staging.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-customer-staging"
            manifestPlaceholders["deepLinkPathPrefix"] = "/app"
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Planext4u Customer")
            manifestPlaceholders["deepLinkHost"] = "planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-customer"
            manifestPlaceholders["deepLinkPathPrefix"] = "/app"
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
