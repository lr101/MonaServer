package de.lrprojects.monaserver.properties

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.token")
data class TokenProperties(
    val refreshTokenExploration: Long,
    val accessTokenExploration: Long,
    val adminAccountName: String
)
