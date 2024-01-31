package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import org.springframework.transaction.annotation.Transactional
import java.time.OffsetDateTime
import java.util.*

@Repository
@Transactional
interface PinRepository : JpaRepository<Pin, Long> {




    @Query(
        value = "SELECT p.*, gp.group_id " +
                "FROM pins p " +
                "JOIN groups_pins gp on p.id = gp.id " +
                "WHERE gp.group_id IN ( " +
                "  SELECT m.group_id FROM members m " +
                "  JOIN groups g on g.group_id = m.group_id " +
                "  WHERE m.username = ?2 OR g.visibility = 0 " +
                "  GROUP BY m.group_id " +
                ") AND p.creation_user = ?1",
        nativeQuery = true
    )
    fun findPinsWithGroupOfUser(username: String, currentUsername: String): MutableList<Pair<Pin, Long>>

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
                "AND p.id IN ?3 ",
        nativeQuery = true
    )
    fun findPinsOfUserInIds(username: String, currentUsername: String, ids: String): MutableList<Pin>

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
                "AND p.creation_user = ?1",
        nativeQuery = true
    )
    fun findPinsOfUserAndGroup(username: String, currentUsername: String, groupId: Long): MutableList<Pin>

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
                "ORDER BY p.creation_date DESC",
        nativeQuery = true
    )
    fun findPinsByGroupAndDate(currentUsername: String, groupId: Long, date: OffsetDateTime): MutableList<Pin>

    @Query("SELECT p.* " +
            "FROM groups_pins gp FULL OUTER JOIN pins p on p.id = gp.id " +
            "WHERE gp.group_id = ?1", nativeQuery = true)
    fun findGroupPinsByGroupId(groupId: Long): List<Pin>


    @Query("SELECT g.* " +
            "FROM groups_pins gp JOIN pins p on p.id = gp.id " +
            "JOIN groups g on g.group_id = gp.group_id " +
            "WHERE p.id = ?1", nativeQuery = true)
    fun findGroupOfPin(pinId: Long): Optional<Group>

    @Query("SELECT p.*" +
            " FROM groups_pins gp " +
            " JOIN pins p on p.id = gp.id " +
            " WHERE gp.group_id = ?1 AND p.creation_user = ?2", nativeQuery = true)
    fun findPinsOfUserInGroup(groupId: Long, username: String) : List<Pin>


    @Query("SELECT m.pin, lo_get(m.image) as image FROM monas m" +
            "        WHERE m.pin IN (" +
            "            SELECT gp.id FROM groups_pins gp" +
            "                WHERE group_id IN (" +
            "                    SELECT g.group_id FROM groups g" +
            "                        JOIN members m2 on g.group_id = m2.group_id" +
            "                                    WHERE g.visibility = 0 OR m2.username = ?2" +
            "                                    GROUP BY g.group_id" +
            "                    )" +
            "            )" +
            "        AND m.pin IN ?1 ", nativeQuery = true)
    fun getImagesFromIds(listOfIds: String, username: String) : MutableList<ByteArray>


    @Query("SELECT lo_get(image) FROM pins WHERE id = ?1", nativeQuery = true)
    fun getImage(pinId: Long): Optional<ByteArray>


    @Query("UPDATE pins SET image = lo_from_bytea(0, ?2) WHERE id = ?1", nativeQuery = true)
    fun setImage(pinId: Long, image: ByteArray)
}