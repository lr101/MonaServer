package de.lrprojects.monaserver.properties

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.config")
data class AppProperties(
    val url: String,
    val maxLoginAttempts: Int,
    val firebaseConfigPath: String?
)