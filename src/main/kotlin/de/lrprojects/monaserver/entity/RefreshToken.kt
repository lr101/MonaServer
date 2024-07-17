package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
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
    @JoinColumn(name = "user_id", nullable = false)
    val user: User,

    @CreationTimestamp
    val creationDate: Date? = null,

    @UpdateTimestamp
    val updateDate: Date? = null
)