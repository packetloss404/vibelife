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
    maven("https://hub.spigotmc.org/nexus/content/repositories/snapshots/")
    maven("https://oss.sonatype.org/content/repositories/snapshots/")
    maven("https://jitpack.io")
}

dependencies {
    compileOnly("org.spigotmc:spigot-api:1.21.4-R0.1-SNAPSHOT")
    compileOnly("com.github.MilkBowl:VaultAPI:1.7.1")

    implementation("com.google.code.gson:gson:2.11.0")
}

tasks.shadowJar {
    archiveClassifier.set("")
    relocate("com.google.gson", "com.vibelife.spigot.libs.gson")
}

tasks.build {
    dependsOn(tasks.shadowJar)
}
