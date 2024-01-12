package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.GroupPin
import org.springframework.data.jpa.repository.JpaRepository

interface GroupPinRepository : JpaRepository<GroupPin, Int>