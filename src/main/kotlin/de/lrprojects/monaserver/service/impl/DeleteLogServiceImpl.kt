package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.helper.DeletedEntityType
import de.lrprojects.monaserver.repository.DeleteLogRepository
import de.lrprojects.monaserver.service.api.DeleteLogService
import org.springframework.stereotype.Service
import java.util.*

@Service
class DeleteLogServiceImpl(
    private val deleteLogRepository: DeleteLogRepository,
) : DeleteLogService {
    override fun getDeletedGroups(dateAfter: Date): List<UUID> {
        return deleteLogRepository
            .findByCreationDateAfterAndKey_DeletedEntityType(dateAfter, DeletedEntityType.GROUP)
            .map { it.key.deletedEntityId }.toList()
    }

    override fun getDeletedPins(dateAfter: Date): List<UUID> {
        return deleteLogRepository
            .findByCreationDateAfterAndKey_DeletedEntityType(dateAfter, DeletedEntityType.PIN)
            .map { it.key.deletedEntityId }.toList()
    }

    override fun getDeletedUsers(dateAfter: Date): List<UUID> {
        return deleteLogRepository
            .findByCreationDateAfterAndKey_DeletedEntityType(dateAfter, DeletedEntityType.USER)
            .map { it.key.deletedEntityId }.toList()
    }
}