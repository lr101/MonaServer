package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Pin
import org.springframework.data.jpa.repository.JpaRepository

interface PinRepository : JpaRepository<Pin, Int>