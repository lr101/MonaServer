package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.properties.DbConstants.ID
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
@Table(name = "users_seasons")
data class UserSeason(
    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,
    @ManyToOne
    @JoinColumn(name = "user_id", referencedColumnName = ID, nullable = false)
    val user: User,
    @ManyToOne
    @JoinColumn(name = "season_id", referencedColumnName = ID, nullable = false)
    val season: Season,
    @Column(nullable = false)
    val rank: Int,
    @Column(nullable = false)
    val numberOfPins: Int,
    @CreationTimestamp
    val creationDate: OffsetDateTime? = null,
    @UpdateTimestamp
    val updateDate: OffsetDateTime? = null
)
