package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.helper.EmbeddedDeletedEntityKey
import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import java.util.*

@Entity
@Table(name = "delete_log")
data class DeleteLog (
    @EmbeddedId
    val key: EmbeddedDeletedEntityKey,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var creationDate: Date? = null
)