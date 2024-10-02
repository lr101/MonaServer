package de.lrprojects.monaserver.helper

import jakarta.persistence.Embeddable
import java.io.Serializable
import java.util.*

@Embeddable
data class EmbeddedDeletedEntityKey (
    val deletedEntityType: DeletedEntityType,
    val deletedEntityId: UUID
): Serializable
