package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.properties.DbConstants.FK_MEMBERS_GROUP_ID
import de.lrprojects.monaserver.properties.DbConstants.FK_MEMBERS_USERNAME
import de.lrprojects.monaserver.properties.DbConstants.GROUP_ID
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.USER_ID
import jakarta.persistence.Embeddable
import jakarta.persistence.ForeignKey
import jakarta.persistence.JoinColumn
import jakarta.persistence.OneToOne
import java.io.Serializable

@Embeddable
data class EmbeddedMemberKey(
    @JoinColumn(name = GROUP_ID, referencedColumnName = ID, foreignKey = ForeignKey(name = FK_MEMBERS_GROUP_ID))
    @OneToOne
    val group: Group,
    @JoinColumn(name = USER_ID, referencedColumnName = ID, foreignKey = ForeignKey(name = FK_MEMBERS_USERNAME))
    @OneToOne
    val user: User
): Serializable {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as EmbeddedMemberKey

        if (group != other.group) return false
        if (user != other.user) return false

        return true
    }

    override fun hashCode(): Int {
        var result = group.hashCode()
        result = 31 * result + user.hashCode()
        return result
    }


}
