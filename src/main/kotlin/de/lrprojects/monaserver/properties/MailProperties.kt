package de.lrprojects.monaserver.properties

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.mail")
data class MailProperties(
    val from: String,
    val username: String,
    val password: String,
    val host: String,
    val port: Int,
    val protocol: String
)