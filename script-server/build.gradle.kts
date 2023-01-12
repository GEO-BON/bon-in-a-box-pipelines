import org.gradle.api.tasks.testing.logging.TestExceptionFormat

val ktor_version: String by project
val kotlin_version: String by project
val logback_version: String by project

plugins {
    kotlin("jvm") version "1.8.0"
    id("io.ktor.plugin") version "2.2.2"
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
    implementation("io.ktor:ktor-server-content-negotiation-jvm:$ktor_version")
    implementation("io.ktor:ktor-server-core-jvm:$ktor_version")
    implementation("io.ktor:ktor-serialization-gson-jvm:$ktor_version")
    implementation("io.ktor:ktor-server-netty-jvm:$ktor_version")
    implementation("ch.qos.logback:logback-classic:$logback_version")
    implementation("io.ktor:ktor-server-config-yaml:$ktor_version")

    // https://mvnrepository.com/artifact/org.json/json
    implementation("org.json:json:20220924")

    // https://mvnrepository.com/artifact/org.yaml/snakeyaml
    implementation("org.yaml:snakeyaml:1.33")
    
    testImplementation("io.ktor:ktor-server-tests-jvm:$ktor_version")
    testImplementation("org.jetbrains.kotlin:kotlin-test-junit:$kotlin_version")
    testImplementation("io.mockk:mockk:1.13.2")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.6.4")
    testImplementation("io.kotest:kotest-runner-junit5:5.5.4")

}