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
import jakarta.persistence.OneToOne
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
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
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    val creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    val updateDate: OffsetDateTime? = null,

    @Column
    var likeAll: Boolean = false,

    @Column
    var likeLocation: Boolean = false,

    @Column
    var likePhotography: Boolean = false,

    @Column
    var likeArt: Boolean = false
) {

    override fun hashCode(): Int {
        return id.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Like

        if (id != other.id) return false
        if (pin != other.pin) return false
        if (user != other.user) return false
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false
        if (likeAll != other.likeAll) return false
        if (likeLocation != other.likeLocation) return false
        if (likePhotography != other.likePhotography) return false
        if (likeArt != other.likeArt) return false

        return true
    }
}
