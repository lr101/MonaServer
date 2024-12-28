package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.entity.Group
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.properties.DbConstants.GROUP_ID
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.USER_ID
import jakarta.persistence.CascadeType
import jakarta.persistence.Embeddable
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToOne
import java.io.Serializable

@Embeddable
data class EmbeddedMemberKey(
    @JoinColumn(name = GROUP_ID, referencedColumnName = ID)
    @ManyToOne(fetch = FetchType.LAZY)
    val group: Group,
    @JoinColumn(name = USER_ID, referencedColumnName = ID)
    @OneToOne(cascade = [CascadeType.REMOVE], orphanRemoval = true)
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
