package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.GroupPin
import de.lrprojects.monaserver.entity.Pin
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository

@Repository
interface GroupPinRepository : JpaRepository<GroupPin, Long> {

    @Query("SELECT p.*" +
            " FROM groups_pins gp " +
            " JOIN pins p on p.id = gp.id " +
            " WHERE gp.group_id = ?1 AND p.creation_user = ?2", nativeQuery = true)
    fun findPinsOfUserInGroup(groupId: Long, username: String) : List<Pin>

    @Query("SELECT p.* " +
        "FROM groups_pins gp FULL OUTER JOIN pins p on p.id = gp.id " +
        "WHERE gp.group_id = ?1", nativeQuery = true)
    fun findGroupPinsByGroupId(groupId: Long): List<Pin>
}