package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.entity.keys.EmbeddedDeletedEntityKey
import de.lrprojects.monaserver.properties.DbConstants.DELETE_LOG
import jakarta.persistence.Column
import jakarta.persistence.EmbeddedId
import jakarta.persistence.Entity
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import org.hibernate.annotations.CreationTimestamp
import java.time.OffsetDateTime

@Entity
@Table(name = DELETE_LOG)
data class DeleteLog (
    @EmbeddedId
    val key: EmbeddedDeletedEntityKey,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var creationDate: OffsetDateTime? = null
)