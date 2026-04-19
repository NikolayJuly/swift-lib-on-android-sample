// Top-level build file. Module-level config lives in each subproject's build.gradle.kts.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.protobuf) apply false
}

// Clones + builds swift-android-bundler at a pinned tag into .tools/.
// Idempotent — bootstrap script no-ops once the marker file exists.
val bootstrapSwiftAndroidBundler by tasks.registering(Exec::class) {
    description = "Builds the swift-android-bundler CLI into .tools/ (pinned via Scripts/bootstrap-tools.sh)"
    group = "build setup"
    workingDir = rootProject.projectDir.parentFile
    commandLine("bash", "Scripts/bootstrap-tools.sh")
    inputs.file(rootProject.projectDir.parentFile.resolve("Scripts/bootstrap-tools.sh"))
    outputs.file(rootProject.projectDir.parentFile.resolve(".tools/.bootstrapped-swift-android-bundler-v0.3.0"))
}

// Builds Swift `.so` libs + manifests via Scripts/build-android-so.sh.
// Wired into each module's preBuild via dependsOn below — first Gradle build
// produces the native libs automatically; subsequent runs are incremental
// (swift-android-bundler caches via SwiftPM's own incremental build).
val buildSwiftLibs by tasks.registering(Exec::class) {
    description = "Builds PokemonKit .so files for Android via swift-android-bundler"
    group = "build"
    dependsOn(bootstrapSwiftAndroidBundler)
    workingDir = rootProject.projectDir.parentFile
    commandLine("bash", "Scripts/build-android-so.sh")
    inputs.dir(rootProject.projectDir.parentFile.resolve("Modules/PokemonKit/Sources"))
    inputs.dir(rootProject.projectDir.parentFile.resolve("Toolkit"))
    inputs.file(rootProject.projectDir.parentFile.resolve("Modules/PokemonKit/Package.swift"))
    inputs.file(rootProject.projectDir.parentFile.resolve("Scripts/build-android-so.sh"))
    outputs.dir(project(":swift-runtime").projectDir.resolve("src/main/jniLibs"))
    outputs.dir(project(":pokemon-swift").projectDir.resolve("src/main/jniLibs"))
    outputs.file(project(":swift-runtime").projectDir.resolve("src/main/assets/swift-libs-manifest.json"))
    outputs.file(project(":pokemon-swift").projectDir.resolve("src/main/assets/pokemon-libs-manifest.json"))
}
