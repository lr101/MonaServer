package de.lrprojects.monaserver.entity.keys

import de.lrprojects.monaserver.types.DeletedEntityType
import jakarta.persistence.Embeddable
import java.io.Serializable
import java.util.*

@Embeddable
data class EmbeddedDeletedEntityKey (
    val deletedEntityType: DeletedEntityType,
    val deletedEntityId: UUID
): Serializable {

    override fun hashCode(): Int {
        val result = deletedEntityType.name.hashCode()
        return 31 * result + deletedEntityType.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EmbeddedDeletedEntityKey

        if (deletedEntityType != other.deletedEntityType) return false
        if (deletedEntityId != other.deletedEntityId) return false

        return true
    }
}
