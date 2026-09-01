plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val protectedFirebaseConfigPresent =
    file("google-services.json").isFile ||
        listOf("development", "staging", "production").any {
            file("src/$it/google-services.json").isFile
        }
if (protectedFirebaseConfigPresent) {
    apply(plugin = "com.google.gms.google-services")
}

val releaseKeystorePath = providers.environmentVariable("ANDROID_KEYSTORE_PATH").orNull
val releaseKeystorePassword = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").orNull
val releaseKeyAlias = providers.environmentVariable("ANDROID_KEY_ALIAS").orNull
val releaseKeyPassword = providers.environmentVariable("ANDROID_KEY_PASSWORD").orNull
val protectedAndroidSigningPresent = listOf(
    releaseKeystorePath,
    releaseKeystorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { !it.isNullOrBlank() } && file(releaseKeystorePath ?: "missing").isFile

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
            manifestPlaceholders["usesCleartextTraffic"] = "true"
        }
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            resValue("string", "app_name", "Planext4u Vendor Staging")
            manifestPlaceholders["deepLinkHost"] = "staging.planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-vendor-staging"
            manifestPlaceholders["deepLinkPathPrefix"] = "/vendor"
            manifestPlaceholders["usesCleartextTraffic"] = "false"
        }
        create("production") {
            dimension = "environment"
            resValue("string", "app_name", "Planext4u Vendor")
            manifestPlaceholders["deepLinkHost"] = "planext4u.net"
            manifestPlaceholders["deepLinkScheme"] = "planext4u-vendor"
            manifestPlaceholders["deepLinkPathPrefix"] = "/vendor"
            manifestPlaceholders["usesCleartextTraffic"] = "false"
        }
    }

    signingConfigs {
        if (protectedAndroidSigningPresent) {
            create("protectedRelease") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (protectedAndroidSigningPresent) {
                signingConfig = signingConfigs.getByName("protectedRelease")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val productionReleaseRequested = allTasks.any {
        it.name.contains("production", ignoreCase = true) &&
            it.name.contains("release", ignoreCase = true)
    }
    if (productionReleaseRequested && !protectedAndroidSigningPresent) {
        throw GradleException(
            "Production release signing must be supplied by the protected CI environment.",
        )
    }
}

flutter {
    source = "../.."
}
