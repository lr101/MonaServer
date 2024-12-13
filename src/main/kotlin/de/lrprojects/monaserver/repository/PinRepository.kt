package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Pin
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
interface PinRepository : JpaRepository<Pin, UUID> {

    @Query("SELECT  p.* FROM pins p " +
            " WHERE " +
            "p.group_id IN ( " +
            "  SELECT m.group_id FROM members m " +
            "  JOIN groups g on g.id = m.group_id " +
            "  WHERE m.user_id = cast (:currentUserId as uuid) OR g.visibility = 0 " +
            "  GROUP BY m.group_id) " +
            " AND ( cast(:ids as uuid[]) IS NULL OR p.id IN (:ids) ) " +
            " AND ( cast(:userId as uuid) IS NULL OR p.creator_id = :userId )" +
            " AND ( cast(:groupId as uuid) IS NULL OR p.group_id = :groupId)" +
            " AND ( cast(:updatedAfter as timestamp) IS NULL OR p.update_date > :updatedAfter)" +
            " ORDER BY p.creation_date DESC", nativeQuery = true)
    fun getImagesFromIds(@Param("ids") listOfIds: Array<UUID>?,
                         @Param("userId") userId: UUID?,
                         @Param("groupId") groupId: UUID?,
                         @Param("currentUserId") currentUsername: UUID,
                         @Param("updatedAfter") updatedAfter: OffsetDateTime?,
                         pageable: Pageable
    ) :  Page<Pin>

    @Query("SELECT p.id FROM Pin p WHERE p.group = :group")
    fun findAllByGroup(group: Group): List<UUID>

    @Query("SELECT p.id FROM Pin p WHERE p.user = :user")
    fun findAllByUser(user: User): List<UUID>

    fun findByCreationDateAndUserAndLatitudeAndLongitude(creationDate: OffsetDateTime, user: User,latitude: Double, longitude: Double): Optional<Pin>

}