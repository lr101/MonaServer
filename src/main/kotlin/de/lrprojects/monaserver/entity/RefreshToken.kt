package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.properties.DbConstants.USER_ID
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
data class RefreshToken(
    @Id
    @GeneratedValue
    val id: UUID? = null,

    @Column(nullable = false, unique = true)
    val token: UUID,

    @Column(nullable = false)
    var lastActiveDate: OffsetDateTime,

    @ManyToOne
    @JoinColumn(name = USER_ID, nullable = false)
    val user: User,

    @CreationTimestamp
    val creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    val updateDate: OffsetDateTime? = null
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is RefreshToken) return false

        if (id != null && other.id != null) {
            return id == other.id
        }

        return token == other.token &&
                lastActiveDate == other.lastActiveDate &&
                user.id == other.user.id
    }

    override fun hashCode(): Int {
        return id?.hashCode() ?: token.hashCode()
    }


}
