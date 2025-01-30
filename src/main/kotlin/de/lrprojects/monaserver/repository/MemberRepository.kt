package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Member
import de.lrprojects.monaserver.entity.keys.EmbeddedMemberKey
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.util.*

@Repository
interface MemberRepository : JpaRepository<Member, EmbeddedMemberKey> {
    @Modifying
    fun deleteById_Group_IdAndId_User_Id(groupId: UUID, userId: UUID)

    fun existsById_Group_IdAndId_User_Id(groupId: UUID, userId: UUID): Boolean

    @Query("SELECT COUNT(*) FROM members WHERE group_id = :groupId", nativeQuery = true)
    fun countByGroup(groupId: UUID): Long
}
