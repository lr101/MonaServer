package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.config.DbConstants.DELETE_LOG
import de.lrprojects.monaserver.helper.EmbeddedDeletedEntityKey
import jakarta.persistence.*
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