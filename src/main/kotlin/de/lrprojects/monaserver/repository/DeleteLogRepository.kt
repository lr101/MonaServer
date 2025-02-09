package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.DeleteLog
import de.lrprojects.monaserver.types.DeletedEntityType
import de.lrprojects.monaserver.entity.keys.EmbeddedDeletedEntityKey
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.time.OffsetDateTime

@Repository
interface DeleteLogRepository : JpaRepository<DeleteLog, EmbeddedDeletedEntityKey> {
    fun findByCreationDateAfterAndKey_DeletedEntityType(creationDate: OffsetDateTime, deletedEntityType: DeletedEntityType): List<DeleteLog>
}
