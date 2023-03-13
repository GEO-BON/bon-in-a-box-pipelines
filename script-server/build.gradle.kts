import org.gradle.api.tasks.testing.logging.TestExceptionFormat

val ktorVersion: String by project
val kotlinVersion: String by project
val logbackVersion: String by project

plugins {
    kotlin("jvm") version "1.8.0"
    id("io.ktor.plugin")
}

group = "org.geobon"
version = "1.0.0"
application {
    mainClass.set("io.ktor.server.netty.EngineMain")

    val isDevelopment: Boolean = ("true" == System.getenv("DEV"))
    applicationDefaultJvmArgs = listOf("-Dio.ktor.development=$isDevelopment")
}

repositories {
    mavenCentral()
}

tasks.test {
    if (javaVersion.isCompatibleWith(JavaVersion.VERSION_17)) {
        // See https://kotest.io/docs/next/extensions/system_extensions.html#system-environment.
        jvmArgs("--add-opens=java.base/java.util=ALL-UNNAMED")
    }

    environment(mapOf(
        "SCRIPT_LOCATION" to "$projectDir/src/test/resources/scripts/",
        "PIPELINES_LOCATION" to "$projectDir/src/test/resources/pipelines/",
        "OUTPUT_LOCATION" to "$projectDir/src/test/resources/outputs/"
    ))

    testLogging {
        showStandardStreams = true
		events("skipped", "failed")
		exceptionFormat = TestExceptionFormat.FULL
	}
}

dependencies {
    implementation("io.ktor:ktor-server-content-negotiation-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-core-jvm:$ktorVersion")
    implementation("io.ktor:ktor-serialization-gson-jvm:$ktorVersion")
    implementation("io.ktor:ktor-server-netty-jvm:$ktorVersion")
    implementation("ch.qos.logback:logback-classic:1.4.5")
    implementation("io.ktor:ktor-server-config-yaml:$ktorVersion")

    // https://mvnrepository.com/artifact/org.json/json
    implementation("org.json:json:20220924")

    // https://mvnrepository.com/artifact/org.yaml/snakeyaml
    implementation("org.yaml:snakeyaml:1.33")
    
    testImplementation("io.ktor:ktor-server-tests-jvm:$ktorVersion")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:$kotlinVersion")
    testImplementation("io.mockk:mockk:1.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.6.4")
    testImplementation("io.kotest:kotest-runner-junit5:5.5.4")

}