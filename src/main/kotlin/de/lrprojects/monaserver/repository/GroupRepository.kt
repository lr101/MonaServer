package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import org.springframework.data.jpa.repository.JpaRepository

interface GroupRepository : JpaRepository<Group, Int>