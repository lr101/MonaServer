package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.time.OffsetDateTime
import java.util.*

@Entity
@Table(name = "seasons")
data class Season(
    @Id
    @GeneratedValue
    val id: UUID = UUID.randomUUID(),
    @Column(unique = true, nullable = false)
    val seasonNumber: Int,
    @Column(nullable = false)
    val year: Int,
    @Column(nullable = false)
    val month: Int,
    @Column(nullable = false)
    val creationDate: OffsetDateTime = OffsetDateTime.now(),
    @Column(nullable = false)
    val updateDate: OffsetDateTime = OffsetDateTime.now()
)
