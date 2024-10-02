package de.lrprojects.monaserver.service.api

import java.time.OffsetDateTime
import java.util.*

interface DeleteLogService {

    fun getDeletedGroups(dateAfter: OffsetDateTime): List<UUID>

    fun getDeletedPins(dateAfter: OffsetDateTime): List<UUID>

    fun getDeletedUsers(dateAfter: OffsetDateTime): List<UUID>
}