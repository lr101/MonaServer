package de.lrprojects.monaserver.properties

import org.springframework.boot.context.properties.ConfigurationProperties
import java.time.OffsetDateTime
import java.util.*

@ConfigurationProperties(prefix = "app.achievements")
data class AchievementProperties (
    val createdBefore: OffsetDateTime,
    val monaGroupId: UUID
)