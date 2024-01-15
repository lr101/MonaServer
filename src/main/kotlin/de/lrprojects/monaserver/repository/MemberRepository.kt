package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Member
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query

interface MemberRepository : JpaRepository<Member, Long> {

    @Query("SELECT username, count(creation_user)::int as points FROM members m" +
            "              LEFT JOIN (SELECT pins.id, creation_user FROM pins JOIN public.groups_pins gp on pins.id = gp.id" +
            "                         WHERE gp.group_id = ?1) as pg on pg.creation_user = m.username" +
            "              WHERE group_id = ?1" +
            "           GROUP BY username ORDER BY points DESC, username", nativeQuery = true)
    fun getRanking(groupId: Long) : Pair<Long, String>
}