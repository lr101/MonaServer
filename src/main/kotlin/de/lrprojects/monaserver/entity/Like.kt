package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.PIN_ID
import de.lrprojects.monaserver.properties.DbConstants.USER_ID
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.Table
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.*

@Entity
@Table(name = "likes")
data class Like(

    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = PIN_ID, referencedColumnName = ID, nullable = false)
    @JsonIgnore
    var pin: Pin? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = USER_ID, referencedColumnName = ID, nullable = false)
    @JsonIgnore
    var user: User? = null,

    @CreationTimestamp
    @Column(nullable = false)
    val creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Column(nullable = false)
    val updateDate: OffsetDateTime? = null,

    @Column(nullable = false)
    var likeAll: Boolean = false,

    @Column(nullable = false)
    var likeLocation: Boolean = false,

    @Column(nullable = false)
    var likePhotography: Boolean = false,

    @Column(nullable = false)
    var likeArt: Boolean = false
) {

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Like) return false

        if (id != null && other.id != null) {
            return id == other.id
        }

        return pin?.id == other.pin?.id &&
                user?.id == other.user?.id
    }

    override fun hashCode(): Int {
        return id?.hashCode() ?: Objects.hash(pin?.id, user?.id)
    }
}
