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
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
data class UserAchievement (
    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,

    @Column
    val achievementId: Int,

    @JoinColumn(name = USER_ID, referencedColumnName = ID)
    @ManyToOne(cascade = [CascadeType.ALL])
    @JsonIgnore
    val user: User,

    @Column
    var claimed: Boolean,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: OffsetDateTime? = null,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as UserAchievement

        if (id != other.id) return false
        if (achievementId != other.achievementId) return false
        if (user != other.user) return false
        if (claimed != other.claimed) return false
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }
}