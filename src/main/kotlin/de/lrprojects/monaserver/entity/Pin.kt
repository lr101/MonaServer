package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.types.DeletedEntityType
import de.lrprojects.monaserver.entity.keys.PreDeleteEntity
import de.lrprojects.monaserver.properties.DbConstants.CREATOR_ID
import de.lrprojects.monaserver.properties.DbConstants.GROUP_ID
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.PIN
import de.lrprojects.monaserver.properties.DbConstants.PINS
import de.lrprojects.monaserver.properties.DbConstants.STATE_PROVINCE_ID
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToMany
import jakarta.persistence.OneToOne
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import jakarta.persistence.Transient
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import javax.sql.DataSource

@Entity
@Table(name = PINS)
class Pin (

    @Column(nullable = false)
    var latitude: Double = 0.0,

    @Column(nullable = false)
    var longitude: Double = 0.0,

    @Column(nullable = false)
    @Temporal(TemporalType.TIMESTAMP)
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: OffsetDateTime? = null,

    @Column
    var description: String? = null,

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = CREATOR_ID, referencedColumnName = ID, nullable = false)
    var user: User? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = GROUP_ID)
    var group: Group? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = STATE_PROVINCE_ID)
    var location: Boundary? = null,

    @Column(nullable = false)
    var isDeleted: Boolean = false,

    @OneToMany(mappedBy = PIN, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var like: List<Like> = emptyList(),

    @Transient
    private var dataSource: DataSource? = null
): PreDeleteEntity() {
    override fun getDeletedEntityType() = DeletedEntityType.PIN

    override fun hashCode(): Int {
        return id.hashCode()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Pin

        if (latitude != other.latitude) return false
        if (longitude != other.longitude) return false
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false
        if (user != other.user) return false
        if (group != other.group) return false
        if (isDeleted != other.isDeleted) return false
        if (dataSource != other.dataSource) return false

        return true
    }
}