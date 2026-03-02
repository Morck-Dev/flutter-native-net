group = "com.example.native_net"
version = "1.0-SNAPSHOT"

buildscript {
    val kotlinVersion = "2.2.20"
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    }
}

rootProject.allprojects {
    repositories {
        // Local Maven repo where the downloaded AAR is stored
        maven {
            url = uri("${rootProject.layout.buildDirectory.get()}/native_net/aar_maven")
        }
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

android {
    namespace = "com.example.native_net"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            all {
                it.useJUnitPlatform()
                it.outputs.upToDateWhen { false }
                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }
            }
        }
    }
}

/**
 * Downloads the prebuilt AAR from GitHub Releases on first build,
 * places it into a local Maven repo structure so Gradle can resolve it
 * as a normal dependency. Mirrors the approach used by flutter_curl.
 */
fun downloadAar(url: String, targetName: String): String {
    val aarFile = File("${rootProject.layout.buildDirectory.get()}/native_net/$targetName")
    aarFile.parentFile.mkdirs()

    if (!aarFile.exists()) {
        // Copy the local Maven POM to the build directory
        copy {
            from("$projectDir/maven")
            into("${rootProject.layout.buildDirectory.get()}/native_net/aar_maven")
        }
        // Download the AAR from GitHub Releases
        logger.lifecycle("[native_net] Downloading prebuilt AAR from: $url")
        try {
            java.net.URI(url).toURL().openStream().use { input ->
                aarFile.outputStream().use { output ->
                    input.copyTo(output)
                }
            }
            logger.lifecycle("[native_net] AAR downloaded to: ${aarFile.absolutePath}")
        } catch (e: Exception) {
            logger.warn("[native_net] Failed to download AAR: ${e.message}")
            logger.warn("[native_net] Build will fail if no native library is available.")
            throw e
        }
    } else {
        logger.lifecycle("[native_net] Using cached AAR: ${aarFile.absolutePath}")
    }

    return "com.example:native_net:0.0.1"
}

dependencies {
    implementation(
        downloadAar(
            "https://github.com/Morck-Dev/flutter-native-net/releases/download/v0.3.1/native_net.aar",
            "aar_maven/com/example/native_net/0.0.1/native_net-0.0.1.aar"
        )
    )
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}
