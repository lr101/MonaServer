package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.dto.SmallGroupDto
import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.model.GroupSmall
import jakarta.persistence.ColumnResult
import jakarta.persistence.ConstructorResult
import jakarta.persistence.SqlResultSetMapping
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Repository
@Transactional
interface GroupRepository : JpaRepository<Group, Long> {

    @Query( "SELECT g.* FROM groups g " +
            "    WHERE g.group_id IN " +
            "      (SELECT members.group_id FROM members WHERE username = :username) " +
            "AND ( :search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%')))" +
            "AND ( cast(:ids as bigint[]) IS NULL OR g.group_id IN (:ids) )", nativeQuery = true)
    fun searchInUserGroup(@Param("username") username: String, @Param("search") searchTerm: String?,@Param("ids") listOfIds: Array<Long>?) : List<Group>

    @Query( "SELECT g.* FROM groups g " +
            "    WHERE g.group_id NOT IN " +
            "      (SELECT members.group_id FROM members WHERE username = :username) " +
            "AND ( :search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%')))" +
            "AND ( cast(:ids as bigint[]) IS NULL OR g.group_id IN (:ids) )", nativeQuery = true)
    fun searchInNotUserGroup(@Param("username") username: String, @Param("search") searchTerm: String?, @Param("ids") listOfIds: Array<Long>?) : List<Group>

    @Query( "SELECT g.* FROM groups g " +
            "WHERE ( :search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%')))" +
            "AND ( cast(:ids as bigint[]) IS NULL OR g.group_id IN (:ids) )", nativeQuery = true)
    fun searchGroups(@Param("ids") listOfIds: Array<Long>?, @Param("search") searchTerm: String?) : List<Group>


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