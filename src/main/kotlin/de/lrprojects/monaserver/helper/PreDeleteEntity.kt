package de.lrprojects.monaserver.helper

import jakarta.persistence.*
import java.io.Serializable
import java.util.*

@MappedSuperclass
@EntityListeners(EntityListener::class)
abstract class PreDeleteEntity(
    @Id
    @GeneratedValue
    @Column(nullable = false)
    var id: UUID? = null,

): Serializable {

    abstract fun getDeletedEntityType(): DeletedEntityType
}
