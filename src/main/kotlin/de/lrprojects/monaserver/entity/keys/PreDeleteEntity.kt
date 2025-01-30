package de.lrprojects.monaserver.entity.keys

import de.lrprojects.monaserver.helper.EntityListener
import de.lrprojects.monaserver.types.DeletedEntityType
import jakarta.persistence.Column
import jakarta.persistence.EntityListeners
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.MappedSuperclass
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
