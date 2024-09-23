package de.lrprojects.monaserver.service.api

import java.util.*

interface DeleteLogService {

    fun getDeletedGroups(dateAfter: Date): List<UUID>

    fun getDeletedPins(dateAfter: Date): List<UUID>

    fun getDeletedUsers(dateAfter: Date): List<UUID>
}