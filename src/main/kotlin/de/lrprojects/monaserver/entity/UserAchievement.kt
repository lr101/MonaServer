package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.USER_ID
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
data class UserAchievement (
    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,

    @Column(nullable = false)
    val achievementId: Int,

    @JoinColumn(name = USER_ID, referencedColumnName = ID, nullable = false)
    @ManyToOne(cascade = [CascadeType.ALL])
    @JsonIgnore
    val user: User,

    @Column(nullable = false)
    var claimed: Boolean,

    @CreationTimestamp
    @Column(nullable = false)
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Column(nullable = false)
    var updateDate: OffsetDateTime? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is UserAchievement) return false

        if (id != null && other.id != null) {
            return id == other.id
        }

        return achievementId == other.achievementId &&
                user.id == other.user.id
    }

    override fun hashCode(): Int {
        return id?.hashCode() ?: achievementId.hashCode()
    }
}