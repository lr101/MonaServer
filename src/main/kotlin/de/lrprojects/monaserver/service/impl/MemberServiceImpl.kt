package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.Member
import de.lrprojects.monaserver.service.api.MemberService
import org.openapitools.model.GroupSmall
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class MemberServiceImpl : MemberService {
    override fun addMember(username: String): Group {
        TODO("Not yet implemented")
    }

    override fun getMembers(groupId: Long): List<Member> {
        TODO("Not yet implemented")
    }

    override fun deleteMember(username: String) {
        TODO("Not yet implemented")
    }

    override fun getGroupsOfUser(username: String): List<GroupSmall> {
        TODO("Not yet implemented")
    }


}