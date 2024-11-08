package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Member
import de.lrprojects.monaserver.helper.EmbeddedMemberKey
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.CrudRepository
import org.springframework.data.repository.query.Param
import org.springframework.stereotype.Repository
import java.util.*

@Repository
interface MemberRepository : CrudRepository<Member, EmbeddedMemberKey> {
    @Modifying
    @Query("""
        INSERT INTO members (user_id, group_id) values (:userId, :groupId)
    """, nativeQuery = true)
    fun addMemberGroup(@Param("userId") userId: UUID, @Param("groupId") groupId: UUID)

    fun existsById_Group_IdAndId_User_Id(groupId: UUID, userId: UUID): Boolean

    @Query("SELECT COUNT(*) FROM members WHERE group_id = :groupId", nativeQuery = true)
    fun countByGroup(groupId: UUID): Long
}
