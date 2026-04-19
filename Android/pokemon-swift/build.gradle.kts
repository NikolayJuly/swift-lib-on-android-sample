plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.protobuf)
}

android {
    namespace = "com.sample.pokemon.swift"
    compileSdk = 36

    defaultConfig {
        minSdk = 28
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    kotlinOptions {
        jvmTarget = "11"
    }
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

protobuf {
    protoc {
        artifact = libs.protobuf.protoc.get().toString()
    }
    generateProtoTasks {
        all().forEach { task ->
            task.builtins {
                create("java") { option("lite") }
                create("kotlin") { option("lite") }
            }
        }
    }
}

// Mirror the Swift-side proto file into this module's `src/main/proto/` so the
// protobuf-gradle-plugin picks it up from its default location. Single source
// of truth lives in the Swift package; this copy is regenerated each build.
val syncProtoFromSwift by tasks.registering(Copy::class) {
    from(rootProject.projectDir.parentFile.resolve("Modules/PokemonKit/Sources/PokemonKit/pokemon.proto"))
    into(projectDir.resolve("src/main/proto"))
}

tasks.matching { it.name.startsWith("generate") && it.name.endsWith("Proto") }.configureEach {
    dependsOn(syncProtoFromSwift)
}

dependencies {
    api(project(":swift-runtime"))
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    api(libs.protobuf.kotlin.lite)
}

tasks.named("preBuild") {
    dependsOn(rootProject.tasks.named("buildSwiftLibs"))
}
