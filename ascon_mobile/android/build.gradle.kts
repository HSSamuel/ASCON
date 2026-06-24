//
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ This allows the app to recognize google-services.json
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // ✅ THIS BLOCK SILENCE WARNINGS
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")     // Silences "source value 8 is obsolete"
        options.compilerArgs.add("-Xlint:-deprecation") // Silences "VIBRATOR_SERVICE... has been deprecated"
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}