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
    }
}

plugins {
    id("com.android.library")
    id("kotlin-android")
}

// Prebuilt .so files go in src/main/jniLibs/{abi}/libnative_net.so
// Gradle bundles them into the APK automatically.
val jniLibsDir = file("src/main/jniLibs")
val hasPrebuilt = file("src/main/jniLibs/arm64-v8a/libnative_net.so").exists()

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
            // jniLibs is automatically picked up from src/main/jniLibs/
        }
        getByName("test") {
            java.srcDirs("src/test/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21

        if (!hasPrebuilt) {
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

    if (!hasPrebuilt) {
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
    testImplementation("org.jetbrains.kotlin:kotlin-test")
    testImplementation("org.mockito:mockito-core:5.0.0")
}

if (hasPrebuilt) {
    logger.lifecycle("[native_net] Using prebuilt .so from: ${jniLibsDir.absolutePath}")
} else {
    logger.lifecycle("[native_net] No prebuilt .so found, building from source via CMake")
    logger.lifecycle("[native_net] (Run 'bash scripts/download_prebuilt.sh' for prebuilt binaries)")
}
