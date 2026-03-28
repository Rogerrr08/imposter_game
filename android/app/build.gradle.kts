import com.android.build.gradle.internal.api.BaseVariantOutputImpl
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.io.File

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.impostergame.imposter_game"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.impostergame.imposter_game"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as BaseVariantOutputImpl
            val buildTypeName = variant.buildType.name
            val appVersion = variant.versionName ?: "0.0.0"

            output.outputFileName = "yeison-impostor-v${appVersion}-${buildTypeName}.apk"
        }

        val variantNameCapitalized =
            variant.name.replaceFirstChar { char ->
                if (char.isLowerCase()) char.titlecase() else char.toString()
            }

        tasks.named("assemble$variantNameCapitalized").configure {
            doLast {
                val buildTypeName = variant.buildType.name
                val appVersion = variant.versionName ?: "0.0.0"
                val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
                val genericApk = File(flutterApkDir, "app-$buildTypeName.apk")
                val renamedApk = File(
                    flutterApkDir,
                    "yeison-impostor-v${appVersion}-${buildTypeName}.apk",
                )

                if (genericApk.exists()) {
                    genericApk.copyTo(renamedApk, overwrite = true)
                }

                val genericSha = File(flutterApkDir, "app-$buildTypeName.apk.sha1")
                val renamedSha = File(
                    flutterApkDir,
                    "yeison-impostor-v${appVersion}-${buildTypeName}.apk.sha1",
                )

                if (genericSha.exists()) {
                    genericSha.copyTo(renamedSha, overwrite = true)
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
