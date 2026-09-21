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

// Each plugin module's Kotlin must target the same JVM as its Java sources.
// flutter_stripe 14 leaves jvmTarget to AGP 9's Built-in Kotlin, which these
// apps keep off (android.builtInKotlin=false) because the Firebase plugins still
// apply the Kotlin Gradle plugin. Without this, stripe_android's Kotlin falls
// back to the Gradle JDK (21) while its Java targets 17, and the build fails.
subprojects {
    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
        val javaTarget = project.extensions
            .findByType(com.android.build.gradle.BaseExtension::class.java)
            ?.compileOptions?.targetCompatibility
        if (javaTarget != null) {
            compilerOptions.jvmTarget.set(
                org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget.toString()),
            )
        }
    }
}

// A transitive Stripe SDK dependency puts
// com.google.android.gms:play-services-tapandpay (a restricted artifact that is
// not on Google's public Maven) onto the lint-checks classpath, so lintVital
// cannot resolve and the release build fails. Stripe only loads Tap and Pay
// reflectively (Class.forName), so it is never a compile/runtime dependency --
// exclude it from lint classpaths only. Lint itself still runs.
subprojects {
    configurations.matching { it.name.endsWith("LintChecksClasspath") }.configureEach {
        exclude(group = "com.google.android.gms", module = "play-services-tapandpay")
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
