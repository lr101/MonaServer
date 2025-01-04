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
        if (javaClass != other?.javaClass) return false

        other as RefreshToken

        if (id != other.id) return false
        if (token != other.token) return false
        if (lastActiveDate != other.lastActiveDate) return false
        if (user != other.user) return false
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }


}
