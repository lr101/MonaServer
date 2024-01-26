package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Mona
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.util.Optional

@Repository
interface MonaRepository : JpaRepository<Mona, Long> {

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
    fun getImagesFromIds(listOfIds: String, username: String)
}