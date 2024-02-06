package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.model.GroupSmall
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Repository
@Transactional
interface GroupRepository : JpaRepository<Group, Long> {

    @Query( "SELECT g.group_id, g.name, g.visibility FROM groups g " +
            "    WHERE g.group_id IN " +
            "      (SELECT members.group_id FROM members WHERE username = ?1) " +
            "  AND ( ?3 IS NULL OR g.group_id IN (?3) )" +
            "  AND ( ?2 IS NULL OR (g.name ILIKE ?2 OR g.description ILIKE ?2))", nativeQuery = true)
    fun searchInUserGroup(username: String, searchTerm: String?,listOfIds: String?) : List<GroupSmall>

    @Query( "SELECT g.group_id, g.name, g.visibility FROM groups g " +
            "    WHERE g.group_id NOT IN " +
            "      (SELECT members.group_id FROM members WHERE username = ?1) " +
            "  AND ( ?3 IS NULL OR p.id IN (?3) )" +
            "  AND ( ?2 IS NULL OR (g.name ILIKE ?2 OR g.description ILIKE ?2))", nativeQuery = true)
    fun searchInNotUserGroup(username: String, searchTerm: String?,listOfIds: String?) : List<GroupSmall>

    @Query( "SELECT g.group_id, g.name, g.visibility FROM groups g " +
            "WHERE ( ?2 IS NULL OR (g.name ILIKE ?2 OR g.description ILIKE ?2))" +
            "AND ( ?1 IS NULL OR g.group_id IN (?1) )", nativeQuery = true)
    fun searchGroups(listOfIds: String?, searchTerm: String?) : List<GroupSmall>


    @Query("SELECT username, count(creation_user)::int as points FROM members m" +
            "              LEFT JOIN (SELECT pins.id, creation_user FROM pins JOIN public.groups_pins gp on pins.id = gp.id" +
            "                         WHERE gp.group_id = ?1) as pg on pg.creation_user = m.username" +
            "              WHERE group_id = ?1" +
            "           GROUP BY username ORDER BY points DESC, username", nativeQuery = true)
    fun getRanking(groupId: Long) : Pair<Long, String>

    fun findAllByMembersIn(members: MutableCollection<MutableSet<User>>) : MutableList<Group>

    fun findAllByMembersInOrVisibility(members: MutableCollection<MutableSet<User>>, visibility: Int) : MutableList<Group>

    @Query("SELECT m.username FROM members m " +
            "JOIN groups_pins gp on gp.group_id = m.group_id " +
            "WHERE gp.id = ?1", nativeQuery = true)
    fun getGroupMembersByPinId(pinId: Long): MutableList<String>

    @Query("SELECT g.* FROM groups_pins gp " +
            "JOIN groups g ON gp.group_id = g.group_id " +
            "WHERE gp.id = ?1", nativeQuery = true)
    fun findByPin(pinId: Long): Group


}