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

    // ✅ THIS BLOCK SILENCES JAVA WARNINGS
    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
        options.compilerArgs.add("-Xlint:-deprecation")
    }

    // ✅ ADD THIS BLOCK to silence Kotlin warnings from third-party plugins
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        compilerOptions {
            // This is the new, mandatory way to suppress warnings in Kotlin 2.0+
            allWarningsAsErrors.set(false)
            freeCompilerArgs.add("-Xsuppress-warnings")
        }
    } // <--- Added the missing closing brace here
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