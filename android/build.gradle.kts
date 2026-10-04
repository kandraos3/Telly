allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    val configureAndroid = {
        val android = extensions.findByName("android")
        if (android != null) {
            try {
                android.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType).invoke(android, 36)
            } catch (_: Exception) {}
            try {
                android.javaClass.getMethod("setCompileSdk", java.lang.Integer::class.java).invoke(android, 36)
            } catch (_: Exception) {}
        }
    }

    if (state.executed) {
        configureAndroid()
    } else {
        afterEvaluate {
            configureAndroid()
        }
    }

    tasks.configureEach {
        if (name.contains("compile", ignoreCase = true) && name.contains("Kotlin", ignoreCase = true)) {
            try {
                val kotlinOptions = property("kotlinOptions")
                val getLang = kotlinOptions?.javaClass?.getMethod("getLanguageVersion")
                val currentLang = getLang?.invoke(kotlinOptions)?.toString()
                if (currentLang == "1.6" || currentLang == "1.7" || currentLang == "1.8") {
                    val setLang = kotlinOptions?.javaClass?.getMethod("setLanguageVersion", String::class.java)
                    setLang?.invoke(kotlinOptions, "1.9")
                    val setApi = kotlinOptions?.javaClass?.getMethod("setApiVersion", String::class.java)
                    setApi?.invoke(kotlinOptions, "1.9")
                }
            } catch (_: Exception) {}
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

