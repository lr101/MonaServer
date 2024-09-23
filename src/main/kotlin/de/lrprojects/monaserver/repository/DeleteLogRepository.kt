package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.DeleteLog
import de.lrprojects.monaserver.helper.DeletedEntityType
import de.lrprojects.monaserver.helper.EmbeddedDeletedEntityKey
import org.springframework.data.repository.CrudRepository
import org.springframework.stereotype.Repository
import java.util.*

@Repository
interface DeleteLogRepository : CrudRepository<DeleteLog, EmbeddedDeletedEntityKey> {
    fun findByCreationDateAfterAndKey_DeletedEntityType(creationDate: Date, deletedEntityType: DeletedEntityType): List<DeleteLog>
}
