package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query

interface GroupRepository : JpaRepository<Group, Long> {

    @Query( "SELECT g.group_id FROM groups g " +
            "    WHERE g.group_id IN " +
            "      (SELECT members.group_id FROM members WHERE username = ?1) " +
            "  AND (g.name ILIKE ?2 OR g.description ILIKE ?2)", nativeQuery = true)
    fun searchInUserGroup(username: String, searchTerm: String) : List<Long>

    @Query( "SELECT g.group_id FROM groups g " +
            "    WHERE g.group_id NOT IN " +
            "      (SELECT members.group_id FROM members WHERE username = ?1) " +
            "  AND (g.name ILIKE ?2 OR g.description ILIKE ?2)", nativeQuery = true)
    fun searchInNotUserGroup(username: String, searchTerm: String) : List<Long>

}