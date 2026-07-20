import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
}

val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

fun configuredValue(name: String) = providers.environmentVariable(name)
    .orElse(providers.gradleProperty(name))
    .orElse(providers.provider { localProperties.getProperty(name, "") })
    .get()
    .trim()

val deviceEnrollmentUrl = providers.environmentVariable("CONTROLHORARIO_DEVICE_ENROLLMENT_URL")
    .orElse(providers.gradleProperty("CONTROLHORARIO_DEVICE_ENROLLMENT_URL"))
    .get().trim()
val employeeSyncUrl = providers.environmentVariable("CONTROLHORARIO_EMPLOYEE_SYNC_URL")
    .orElse(providers.gradleProperty("CONTROLHORARIO_EMPLOYEE_SYNC_URL"))
    .get().trim()
val attendanceSyncUrl = providers.environmentVariable("CONTROLHORARIO_ATTENDANCE_SYNC_URL")
    .orElse(providers.gradleProperty("CONTROLHORARIO_ATTENDANCE_SYNC_URL"))
    .get().trim()
val supabasePublishableKey = configuredValue("CONTROLHORARIO_SUPABASE_PUBLISHABLE_KEY")
val supabaseUrl = employeeSyncUrl.substringBefore("/functions/v1/")
val employeeUpsertUrl = "$supabaseUrl/functions/v1/employee-upsert"

require(deviceEnrollmentUrl.startsWith("https://")) { "CONTROLHORARIO_DEVICE_ENROLLMENT_URL debe usar HTTPS" }
require(deviceEnrollmentUrl.endsWith("/functions/v1/device-enrollment")) { "CONTROLHORARIO_DEVICE_ENROLLMENT_URL debe apuntar a la Edge Function device-enrollment" }
require(employeeSyncUrl.startsWith("https://") && employeeSyncUrl.endsWith("/functions/v1/employee-sync")) { "CONTROLHORARIO_EMPLOYEE_SYNC_URL debe apuntar por HTTPS a employee-sync" }
require(attendanceSyncUrl.startsWith("https://") && attendanceSyncUrl.endsWith("/functions/v1/attendance-sync")) { "CONTROLHORARIO_ATTENDANCE_SYNC_URL debe apuntar por HTTPS a attendance-sync" }
require(supabasePublishableKey.startsWith("sb_publishable_") || supabasePublishableKey.startsWith("eyJ")) { "CONTROLHORARIO_SUPABASE_PUBLISHABLE_KEY debe contener una clave publicable de Supabase" }

android {
    namespace = "com.example.controlhorario"
    compileSdk { version = release(36) { minorApiLevel = 1 } }
    defaultConfig {
        applicationId = "com.example.controlhorario"
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        resValue("string", "device_enrollment_url", deviceEnrollmentUrl)
        resValue("string", "employee_sync_url", employeeSyncUrl)
        resValue("string", "employee_upsert_url", employeeUpsertUrl)
        resValue("string", "attendance_sync_url", attendanceSyncUrl)
        buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrl\"")
        buildConfigField("String", "SUPABASE_PUBLISHABLE_KEY", "\"$supabasePublishableKey\"")
    }
    buildTypes { release { optimization { enable = false } } }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_11; targetCompatibility = JavaVersion.VERSION_11 }
    buildFeatures { compose = true; resValues = true; buildConfig = true }
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
    implementation("androidx.camera:camera-camera2:1.4.2")
    implementation("androidx.camera:camera-lifecycle:1.4.2")
    implementation("androidx.camera:camera-view:1.4.2")
    implementation("com.google.mlkit:face-detection:16.1.7")
    implementation("org.tensorflow:tensorflow-lite:2.16.1")
    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(libs.androidx.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
    debugImplementation(libs.androidx.compose.ui.tooling)
}
