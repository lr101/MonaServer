package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import de.lrprojects.monaserver.model.PinWithOptionalImage
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.CrudRepository
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Repository
@Transactional
interface PinRepository : CrudRepository<Pin, UUID> {

    @Query(
        value = "SELECT p.*" +
                "FROM pins p " +
                "JOIN groups_pins gp on p.id = gp.id " +
                "WHERE gp.group_id IN ( " +
                "  SELECT m.group_id FROM members m " +
                "  JOIN groups g on g.group_id = m.group_id " +
                "  WHERE m.username = ?2 OR g.visibility = 0 " +
                "  GROUP BY m.group_id) " +
                "AND p.creation_user = ?1 " +
                "AND p.id IN ?3 " +
                "AND p.is_deleted = false",
        nativeQuery = true
    )
    fun findPinsOfUserInIds(userId: UUID, currentUserId: UUID, ids: String): MutableList<Pin>

    @Query(
        value = "SELECT p.*" +
                "FROM pins p " +
                "JOIN groups_pins gp on p.id = gp.id " +
                "WHERE gp.group_id IN ( " +
                "  SELECT m.group_id FROM members m " +
                "  JOIN groups g on g.group_id = m.group_id " +
                "  WHERE m.username = ?2 OR g.visibility = 0 " +
                "  GROUP BY m.group_id) " +
                "AND gp.group_id = ?3 " +
                "AND p.creation_user = ?1 " +
                "AND p.is_deleted = false",
        nativeQuery = true
    )
    fun findPinsOfUserAndGroup(userId: UUID, currentUserId: UUID, groupId: UUID): MutableList<Pin>

    @Query(
        value = "SELECT p.*" +
                "FROM pins p " +
                "JOIN groups_pins gp on p.id = gp.id " +
                "WHERE gp.group_id IN ( " +
                "  SELECT m.group_id FROM members m " +
                "  JOIN groups g on g.group_id = m.group_id " +
                "  WHERE m.username = ?1 OR g.visibility = 0 " +
                "  GROUP BY m.group_id) " +
                "AND gp.group_id = ?2 " +
                "AND p.creation_date > ?3 " +
                "AND p.is_deleted = false " +
                "ORDER BY p.creation_date DESC",
        nativeQuery = true
    )
    fun findPinsByGroupAndDate(currentUserId: UUID, groupId: UUID, date: OffsetDateTime): MutableList<Pin>


    @Query("SELECT p.id, p.creation_date, p.latitude, p.longitude, p.creation_user FROM pins p " +
            "JOIN groups_pins gp on p.id = gp.id WHERE " +
            "gp.group_id IN ( " +
            "  SELECT m.group_id FROM members m " +
                "  JOIN groups g on g.group_id = m.group_id " +
                "  WHERE m.username = cast (:currentUsername as text) OR g.visibility = 0 " +
                "  GROUP BY m.group_id) " +
            " AND ( cast(:ids as bigint[]) IS NULL OR p.id IN (:ids) ) " +
            " AND ( cast(:username as text) IS NULL OR p.creation_user = :username )" +
            " AND ( cast(:groupId as bigint) IS NULL OR gp.group_id = :groupId)" +
            " AND p.is_deleted = false", nativeQuery = true)
    fun getPinsFromIds(
        @Param("ids") listOfIds: Array<UUID>?,
        @Param("username") userId: UUID?,
        @Param("groupId") groupId: UUID?,
        @Param("currentUsername") currentUsername: String
    ) : List<Array<Any>>

    @Query("SELECT  p.id, p.creation_date, p.latitude, p.longitude, p.creation_user, lo_get(p.image) FROM pins p " +
            "JOIN groups_pins gp on p.id = gp.id WHERE " +
            "gp.group_id IN ( " +
            "  SELECT m.group_id FROM members m " +
            "  JOIN groups g on g.group_id = m.group_id " +
            "  WHERE m.username = cast (:currentUsername as text) OR g.visibility = 0 " +
            "  GROUP BY m.group_id) " +
            " AND ( cast(:ids as bigint[]) IS NULL OR p.id IN (:ids) ) " +
            " AND ( cast(:username as text) IS NULL OR p.creation_user = :username )" +
            " AND ( cast(:groupId as bigint) IS NULL OR gp.group_id = :groupId)" +
            " AND p.is_deleted = false", nativeQuery = true)
    fun getImagesFromIds(@Param("ids") listOfIds: Array<UUID>?,
                         @Param("username") userId: UUID?,
                         @Param("groupId") groupId: UUID?,
                         @Param("currentUsername") currentUsername: String
    ) :  List<Array<Any>>

}