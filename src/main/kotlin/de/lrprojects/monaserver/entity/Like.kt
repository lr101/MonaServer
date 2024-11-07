package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
@Table(name = "likes")
data class Like(

    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,

    @Column(name = "pin_id", nullable = false)
    val pinId: UUID,

    @Column(name = "user_id", nullable = false)
    val userId: UUID,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    val creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    val updateDate: OffsetDateTime? = null,

    @Column(name = "like_all", nullable = false)
    var like: Boolean = false,

    @Column(name = "like_location", nullable = false)
    var likeLocation: Boolean = false,

    @Column(name = "like_photography", nullable = false)
    var likePhotography: Boolean = false,

    @Column(name = "like_art", nullable = false)
    var likeArt: Boolean = false
)
