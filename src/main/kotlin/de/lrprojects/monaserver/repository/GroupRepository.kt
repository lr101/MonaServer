package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Repository
@Transactional
interface GroupRepository : JpaRepository<Group, UUID> {


    @Query(
        "SELECT g.* FROM groups g " +
                "WHERE g.id IN " +
                "(SELECT m.group_id FROM members m WHERE m.user_id = :username) " +
                "AND (:search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%'))) " +
                "AND (cast(:ids as uuid[]) IS NULL OR g.id IN (:ids)) " +
                "AND ( cast(:updatedAfter as timestamp) IS NULL OR g.update_date > :updatedAfter)",
        nativeQuery = true
    )
    fun searchInUserGroup(
        @Param("username") userId: UUID,
        @Param("search") searchTerm: String?,
        @Param("ids") listOfIds: Array<UUID>?,
        @Param("updatedAfter") updatedAfter: OffsetDateTime?,
        pageable: Pageable
    ): Page<Group>

    @Query(
        "SELECT g.* FROM groups g " +
                "WHERE g.id NOT IN " +
                "(SELECT m.group_id FROM members m WHERE m.user_id = :username) " +
                "AND (:search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%'))) " +
                "AND (cast(:ids as uuid[]) IS NULL OR g.id IN (:ids)) " +
                "AND ( cast(:updatedAfter as timestamp) IS NULL OR g.update_date > :updatedAfter)",
        nativeQuery = true
    )
    fun searchInNotUserGroup(
        @Param("username") userId: UUID,
        @Param("search") searchTerm: String?,
        @Param("ids") listOfIds: Array<UUID>?,
        @Param("updatedAfter") updatedAfter: OffsetDateTime?,
        pageable: Pageable
    ): Page<Group>

    @Query(
        "SELECT g.* FROM groups g " +
                "WHERE (:search IS NULL OR (g.name ILIKE CONCAT('%', :search, '%') OR g.description ILIKE CONCAT('%', :search, '%'))) " +
                "AND (cast(:ids as uuid[]) IS NULL OR g.id IN (:ids)) " +
                "AND ( cast(:updatedAfter as timestamp) IS NULL OR g.update_date > :updatedAfter)",
        nativeQuery = true
    )
    fun searchGroups(
        @Param("ids") listOfIds: Array<UUID>?,
        @Param("search") searchTerm: String?,
        @Param("updatedAfter") updatedAfter: OffsetDateTime?,
        pageable: Pageable
    ): Page<Group>


    @Query("SELECT m.user_id, u.username, count(pg.creator_id)::int as points, u.selected_batch FROM members m" +
            "              LEFT JOIN (SELECT p.id, p.creator_id FROM pins p" +
            "                         WHERE p.group_id = ?1) as pg on pg.creator_id = m.user_id" +
            "              JOIN users u on u.id = m.user_id" +
            "              WHERE group_id = ?1" +
            "           GROUP BY m.user_id, u.username, u.selected_batch ORDER BY points DESC, m.user_id", nativeQuery = true)
    fun getRanking(groupId: UUID) : List<Array<Any>>

    fun findAllByMembersIn(members: MutableCollection<MutableSet<User>>) : MutableList<Group>

    fun findAllByMembersInOrVisibility(members: MutableCollection<MutableSet<User>>, visibility: Int) : MutableList<Group>

    @Query(
        """
        SELECT g.* FROM groups g
        JOIN pins p on p.group_id = g.id
        WHERE p.id = ?1
        """, nativeQuery = true)
    fun findByPinId(pinId: UUID): Group

    @Query("""
        SELECT m.user_id FROM members m WHERE group_id = :groupId
    """, nativeQuery = true)
    fun findMembersByGroupId(@Param("groupId") groupId: UUID): List<UUID>
}