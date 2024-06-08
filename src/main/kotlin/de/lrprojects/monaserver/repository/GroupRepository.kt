package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.CrudRepository
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.util.*

@Repository
@Transactional
interface GroupRepository : CrudRepository<Group, UUID> {

    @Query( "SELECT g.* FROM groups g " +
            "    WHERE g.id IN " +
            "      (SELECT m.group_id FROM members m WHERE m.user_id = :username) " +
            "AND ( :search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%')))" +
            "AND ( cast(:ids as uuid[]) IS NULL OR g.id IN (:ids) )", nativeQuery = true)
    fun searchInUserGroup(@Param("username") userId: UUID, @Param("search") searchTerm: String?,@Param("ids") listOfIds: Array<UUID>?) : List<Group>

    @Query( "SELECT g.* FROM groups g " +
            "    WHERE g.id NOT IN " +
            "      (SELECT members.group_id FROM members WHERE member_id = :username) " +
            "AND ( :search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%')))" +
            "AND ( cast(:ids as uuid[]) IS NULL OR g.id IN (:ids) )" , nativeQuery = true)
    fun searchInNotUserGroup(@Param("username") userId: UUID, @Param("search") searchTerm: String?, @Param("ids") listOfIds: Array<UUID>?) : List<Group>

    @Query( "SELECT g.* FROM groups g " +
            "WHERE ( :search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%')))" +
            "AND ( cast(:ids as uuid[]) IS NULL OR g.id IN (:ids) )", nativeQuery = true)
    fun searchGroups(@Param("ids") listOfIds: Array<UUID>?, @Param("search") searchTerm: String?) : List<Group>


    @Query("SELECT m.user_id, count(pg.creator_id)::int as points FROM members m" +
            "              LEFT JOIN (SELECT pins.id, creator_id FROM pins JOIN public.groups_pins gp on pins.id = gp.id" +
            "                         WHERE gp.group_id = ?1) as pg on pg.creator_id = m.user_id" +
            "              WHERE group_id = ?1" +
            "           GROUP BY m.user_id ORDER BY points DESC, m.user_id", nativeQuery = true)
    fun getRanking(groupId: UUID) : Pair<UUID, String>

    fun findAllByMembersIn(members: MutableCollection<MutableSet<User>>) : MutableList<Group>

    fun findAllByMembersInOrVisibility(members: MutableCollection<MutableSet<User>>, visibility: Int) : MutableList<Group>

    @Query("SELECT m.user_id FROM members m " +
            "JOIN groups_pins gp on gp.group_id = m.group_id " +
            "WHERE gp.id = ?1", nativeQuery = true)
    fun getGroupMembersByPinId(pinId: UUID): MutableList<String>

    @Query("SELECT g.* FROM groups_pins gp " +
            "JOIN groups g ON gp.group_id = g.id " +
            "WHERE gp.id = ?1 ", nativeQuery = true)
    fun findByPin(pinId: UUID): Group

}