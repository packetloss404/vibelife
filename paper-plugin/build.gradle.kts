plugins {
    java
    id("com.gradleup.shadow") version "8.3.6"
}

group = "com.vibelife"
version = "1.0.0-SNAPSHOT"

java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(21))
    }
}

repositories {
    mavenCentral()
    maven("https://repo.papermc.io/repository/maven-public/")
    maven("https://jitpack.io")
}

dependencies {
    compileOnly("io.papermc.paper:paper-api:1.21.11-R0.1-SNAPSHOT")
    compileOnly("com.github.MilkBowl:VaultAPI:1.7.1")

    implementation("com.google.code.gson:gson:2.11.0")
}

tasks.shadowJar {
    archiveClassifier.set("")
    relocate("com.google.gson", "com.vibelife.paper.libs.gson")
}

tasks.build {
    dependsOn(tasks.shadowJar)
}
