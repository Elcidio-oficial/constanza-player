allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Fix namespace para plugins antigos (on_audio_query etc)
subprojects {
    project.plugins.withId("com.android.library") {
        val android = project.extensions.getByType(
            com.android.build.gradle.LibraryExtension::class.java
        )
        if (android.namespace.isNullOrEmpty()) {
            android.namespace = "com.${project.name.replace("-", ".")}"
        }

        // Remove o atributo `package` legado do AndroidManifest.xml.
        // AGP 8+ não aceita mais definir o namespace via package no manifest
        // (ex.: on_audio_query_android). Auto-reparável a cada build, então
        // funciona mesmo após `flutter pub cache repair`, em outra máquina ou em CI.
        val manifestFile = file("${projectDir}/src/main/AndroidManifest.xml")
        if (manifestFile.exists()) {
            val content = manifestFile.readText()
            if (content.contains("package=")) {
                val cleaned = content.replace(Regex("\\s*package\\s*=\\s*\"[^\"]*\""), "")
                manifestFile.writeText(cleaned)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}