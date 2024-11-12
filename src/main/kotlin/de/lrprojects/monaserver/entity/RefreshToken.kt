package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.properties.DbConstants.USER_ID
import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
data class RefreshToken(
    @Id
    @GeneratedValue
    val id: UUID? = null,

    @Column(nullable = false, unique = true)
    val token: UUID,

    @Column(nullable = false)
    val expiryDate: Date,

    @ManyToOne
    @JoinColumn(name = USER_ID, nullable = false)
    val user: User,

    @CreationTimestamp
    val creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    val updateDate: OffsetDateTime? = null
)
