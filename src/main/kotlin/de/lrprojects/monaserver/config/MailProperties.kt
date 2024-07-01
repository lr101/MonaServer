package de.lrprojects.monaserver.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "mail")
data class MailProperties(
    val from: String,
    val password: String,
    val host: String,
    val port: Int,
    val protocol: String
)