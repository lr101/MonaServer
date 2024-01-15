package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Pin
import jakarta.persistence.Tuple
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query

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
                ") AND p.creation_user = ?1 ORDER BY p.creation_date DESC",
        nativeQuery = true
    )
    fun findPinsOfUser(username: String, currentUsername: String): List<Pair<Pin, Long>>


}