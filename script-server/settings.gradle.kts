rootProject.name = "BON in a Box script server"

pluginManagement {
    val ktorVersion: String by settings
    plugins {
        id("io.ktor.plugin") version ktorVersion
    }
}
