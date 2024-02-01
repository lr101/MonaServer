package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Repository
@Transactional
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


    @Query("SELECT username, count(creation_user)::int as points FROM members m" +
            "              LEFT JOIN (SELECT pins.id, creation_user FROM pins JOIN public.groups_pins gp on pins.id = gp.id" +
            "                         WHERE gp.group_id = ?1) as pg on pg.creation_user = m.username" +
            "              WHERE group_id = ?1" +
            "           GROUP BY username ORDER BY points DESC, username", nativeQuery = true)
    fun getRanking(groupId: Long) : Pair<Long, String>

    fun findAllByMembersIn(members: MutableCollection<MutableSet<User>>) : MutableList<Group>

    fun findAllByGroupIdIn(groupId: List<Long>): MutableList<Group>

    @Query("SELECT lo_get(profile_image) FROM groups WHERE group_id = ?1", nativeQuery = true)
    fun getProfileImage(groupId: Long): Optional<ByteArray>


    @Query("UPDATE groups SET profile_image = lo_from_bytea(0, ?2) WHERE group_id = ?1", nativeQuery = true)
    fun setProfileImage(groupId: Long, image: ByteArray)

    @Query("SELECT m.username FROM members m " +
            "JOIN groups_pins gp on gp.group_id = m.group_id " +
            "WHERE gp.id = ?1")
    fun getGroupMembersByPinId(pinId: Long): MutableList<String>

    fun findByPins(pins: MutableSet<Pin>): Group


}