package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.config.DbConstants.GROUP_ID
import de.lrprojects.monaserver.config.DbConstants.ID
import de.lrprojects.monaserver.config.DbConstants.USER_ID
import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import jakarta.persistence.Embeddable
import jakarta.persistence.JoinColumn
import jakarta.persistence.OneToOne
import java.io.Serializable

@Embeddable
data class EmbeddedMemberKey(
    @JoinColumn(name = GROUP_ID, referencedColumnName = ID)
    @OneToOne
    val group: Group,
    @JoinColumn(name = USER_ID, referencedColumnName = ID)
    @OneToOne
    val user: User
): Serializable
