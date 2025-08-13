
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.0.2") // your version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.10") // your version
        classpath("com.google.gms:google-services:4.3.15")  // Firebase plugin
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Optional if you're using custom build directories
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
