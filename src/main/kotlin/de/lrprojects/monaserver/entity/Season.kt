package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.Table
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
@Table(name = "seasons")
data class Season(
    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,
    @Column(unique = true, nullable = false)
    val seasonNumber: Int,
    @Column(nullable = false)
    val year: Int,
    @Column(nullable = false)
    val month: Int,
    @CreationTimestamp
    val creationDate: OffsetDateTime? = null,
    @UpdateTimestamp
    val updateDate: OffsetDateTime? = null
)
