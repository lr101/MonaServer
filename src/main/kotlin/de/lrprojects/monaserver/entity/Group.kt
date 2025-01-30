package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.types.DeletedEntityType
import de.lrprojects.monaserver.entity.keys.PreDeleteEntity
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.properties.DbConstants.ADMIN_ID
import de.lrprojects.monaserver.properties.DbConstants.GROUPS
import de.lrprojects.monaserver.properties.DbConstants.GROUP_ID
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.MEMBER_GROUP
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import jakarta.persistence.Transient
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import javax.sql.DataSource


@Entity
@Table(name = GROUPS)
data class Group (

    @Column(nullable = false, unique = true)
    var name: String? = null,

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = ADMIN_ID, referencedColumnName = ID)
    var groupAdmin: User? = null,

    @Column
    var description: String? = null,

    @Column(unique = true)
    var inviteUrl: String? = null,

    @Column
    var link: String? = null,

    @Column(nullable = false)
    var visibility: Int = 0,

    @OneToMany(mappedBy = MEMBER_GROUP, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var members: MutableSet<Member> = mutableSetOf(),

    @OneToMany(mappedBy = ID, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var pins: MutableSet<Pin> = HashSet(),

    @OneToMany(mappedBy = GROUP_ID, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var seasons: MutableSet<GroupSeason> = HashSet(),

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: OffsetDateTime? = null,

    @Column(nullable = false)
    var isDeleted: Boolean = false,

    @Transient
    private var dataSource: DataSource? = null

): PreDeleteEntity() {
    fun setInvite() {
        inviteUrl = if (visibility != 0) {
            SecurityHelper.generateAlphabeticRandomString(10)
        } else {
            null
        }
    }

    override fun getDeletedEntityType() = DeletedEntityType.GROUP
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as Group

        if (name != other.name) return false
        if (groupAdmin != other.groupAdmin) return false
        if (description != other.description) return false
        if (inviteUrl != other.inviteUrl) return false
        if (link != other.link) return false
        if (visibility != other.visibility) return false
        if (members != other.members) return false
        if (pins != other.pins) return false
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false
        if (isDeleted != other.isDeleted) return false
        if (dataSource != other.dataSource) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }


}