plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

val deviceEnrollmentUrl = providers.environmentVariable("CONTROLHORARIO_DEVICE_ENROLLMENT_URL")
    .orElse(providers.gradleProperty("CONTROLHORARIO_DEVICE_ENROLLMENT_URL"))
    .get()
    .trim()

require(deviceEnrollmentUrl.startsWith("https://")) {
    "CONTROLHORARIO_DEVICE_ENROLLMENT_URL debe usar HTTPS"
}
require(deviceEnrollmentUrl.endsWith("/functions/v1/device-enrollment")) {
    "CONTROLHORARIO_DEVICE_ENROLLMENT_URL debe apuntar a la Edge Function device-enrollment"
}

android {
    namespace = "com.example.controlhorario"

    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.example.controlhorario"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        resValue("string", "device_enrollment_url", deviceEnrollmentUrl)
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    buildFeatures {
        compose = true
        resValues = true
    }
}

dependencies {

    implementation(files("libs/fplib-reader-v3.jar"))

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)

    implementation("androidx.navigation:navigation-compose:2.9.5")

    implementation(libs.androidx.room.runtime)
    implementation(libs.androidx.room.ktx)
    implementation("androidx.work:work-runtime-ktx:2.10.5")
    ksp(libs.androidx.room.compiler)

    implementation("androidx.biometric:biometric:1.1.0")
    implementation("androidx.fragment:fragment-ktx:1.8.5")

    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)

    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
