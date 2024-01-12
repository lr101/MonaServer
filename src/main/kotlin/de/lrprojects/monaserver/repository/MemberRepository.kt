package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Member
import org.springframework.data.jpa.repository.JpaRepository

interface MemberRepository : JpaRepository<Member, Int>