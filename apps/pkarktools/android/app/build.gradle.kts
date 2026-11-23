import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de release: un keystore propio si está configurado y, si no, la clave
// debug (APK de prueba). Orden: variables de entorno (las usa el workflow de
// GitHub a partir de sus secretos) y luego android/key.properties (local, en
// .gitignore). Ver docs/desarrollo.md#firma-de-android.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
fun signingValue(env: String, prop: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keyProps.getProperty(prop)?.takeIf { it.isNotBlank() }
val releaseStoreFile = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")
val releaseStorePassword = signingValue("ANDROID_STORE_PASSWORD", "storePassword")
val releaseKeyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias")
val releaseKeyPassword = signingValue("ANDROID_KEY_PASSWORD", "keyPassword")
// PKCS12 (por defecto en keytool moderno) o JKS; si no se indica, se deduce.
val releaseStoreType = signingValue("ANDROID_STORE_TYPE", "storeType")
val hasReleaseKey = listOf(releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword).all { it != null } &&
    file(releaseStoreFile!!).exists()

android {
    namespace = "dev.pkarktools.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.pkarktools.app"
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

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                releaseStoreType?.let { storeType = it }
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                logger.warn("PKArkTools: sin keystore de release; el APK se firma con la clave debug.")
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
