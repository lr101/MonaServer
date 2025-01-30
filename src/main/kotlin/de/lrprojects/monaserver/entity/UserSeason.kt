package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import java.time.OffsetDateTime
import java.util.*

@Entity
@Table(name = "users_seasons")
data class UserSeason(
    @Id
    @GeneratedValue
    val id: UUID = UUID.randomUUID(),
    @ManyToOne
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,
    @ManyToOne
    @JoinColumn(name = "season_id", nullable = false)
    val season: Season,
    @Column(nullable = false)
    val rank: Int,
    @Column(nullable = false)
    val numberOfPins: Int,
    @Column(nullable = false)
    val creationDate: OffsetDateTime = OffsetDateTime.now(),
    @Column(nullable = false)
    val updateDate: OffsetDateTime = OffsetDateTime.now()
)
