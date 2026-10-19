import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// Each club is its own Firebase project: src/<flavor>/google-services.json.
// A club without one yet (RYZE, KODE: no project) still builds, with a
// warning, and the app starts with push off (lib/push/push_service.dart).
googleServices {
    missingGoogleServicesStrategy =
        com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy.WARN
}

android {
    namespace = "com.example.o_house"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.o_house"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // One app per club, same code (lib/tenant.dart): each flavor is a club's own
    // Play Store app, with its own id, name and icon (src/<flavor>/res) and,
    // from Step 5, its own src/<flavor>/google-services.json.
    //   flutter run --flavor owest --dart-define=TENANT_NAME=OWEST --dart-define=ENVIRONMENT=dev
    buildFeatures { resValues = true } // off by default since AGP 8: needed for app_name
    flavorDimensions += "tenant"
    productFlavors {
        create("owest") {
            dimension = "tenant"
            // TODO(app id): com.blueribbon.<newapp>.owest once the name is
            // confirmed. Permanent once the Play Store listing exists.
            applicationId = "com.example.o_house"
            resValue("string", "app_name", "O House")
        }
        // Icons: the members' app's per-club launcher icons (src/<flavor>/res).
        // TODO(app id): com.blueribbon.<newapp>.<club>, as for owest. Distinct
        // ids for now so all three install side by side on one test phone.
        create("ryze") {
            dimension = "tenant"
            applicationId = "com.example.o_house.ryze"
            resValue("string", "app_name", "RYZE House")
        }
        create("kode") {
            dimension = "tenant"
            applicationId = "com.example.o_house.kode"
            resValue("string", "app_name", "KODE House")
        }
    }

    // Release signing per club, from a gitignored android/<flavor>.properties
    // (storeFile, storePassword, keyAlias, keyPassword). Without that file a
    // build falls back to the debug keys, so `flutter run --release` still works.
    productFlavors.forEach { flavor ->
        val file = rootProject.file("${flavor.name}.properties")
        flavor.signingConfig = if (file.exists()) {
            val p = Properties().apply { file.inputStream().use { load(it) } }
            signingConfigs.create(flavor.name) {
                storeFile = rootProject.file(p.getProperty("storeFile"))
                storePassword = p.getProperty("storePassword")
                keyAlias = p.getProperty("keyAlias")
                keyPassword = p.getProperty("keyPassword")
            }
        } else {
            signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Video evidence is shrunk to at most 1 MB on the phone (MainActivity's
    // compressVideo, lib/video_shrink.dart). The same Media3 version as
    // video_player's ExoPlayer: two versions of media3-common would clash.
    implementation("androidx.media3:media3-transformer:1.9.2")
    implementation("androidx.media3:media3-effect:1.9.2")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
