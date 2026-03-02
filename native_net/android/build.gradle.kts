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

allprojects {
    repositories {
        google()
        mavenCentral()
        // For local AAR files
        flatDir { dirs("libs") }
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

// Check if prebuilt AAR exists
val prebuiltAar = file("libs/native_net.aar")
val usePrebuiltAar = prebuiltAar.exists()

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

        if (!usePrebuiltAar) {
            // Build from source via CMake (fallback when no prebuilt AAR)
            externalNativeBuild {
                cmake {
                    arguments("-DANDROID_STL=c++_shared")
                }
            }
        }

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    if (!usePrebuiltAar) {
        externalNativeBuild {
            cmake {
                path = file("../src/CMakeLists.txt")
            }
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

dependencies {
    if (usePrebuiltAar) {
        // Use prebuilt AAR (contains .so for all ABIs)
        implementation(files("libs/native_net.aar"))
    }
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}

if (usePrebuiltAar) {
    logger.lifecycle("[native_net] Using prebuilt AAR: ${prebuiltAar.absolutePath}")
} else {
    logger.lifecycle("[native_net] No prebuilt AAR found, will build from source via CMake")
}
