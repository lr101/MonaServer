package de.lrprojects.monaserver.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "token")
data class TokenProperties(
    val refreshTokenExploration: Long,
    val accessTokenExploration: Long,
    val adminAccountName: String
)
