package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Mona
import org.springframework.data.jpa.repository.JpaRepository

interface MonaRepository : JpaRepository<Mona, Int>