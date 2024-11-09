package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.config.DbConstants.ADMIN_ID
import de.lrprojects.monaserver.config.DbConstants.GROUPS
import de.lrprojects.monaserver.config.DbConstants.ID
import de.lrprojects.monaserver.helper.DeletedEntityType
import de.lrprojects.monaserver.helper.PreDeleteEntity
import de.lrprojects.monaserver.helper.SecurityHelper
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

    @Column
    var pinImage: ByteArray? = null,

    @Column
    val groupProfile: ByteArray? = null,

    @OneToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JoinColumn(name = "group_id")
    var members: MutableSet<Member> = mutableSetOf(),

    @OneToMany(mappedBy = ID, fetch = FetchType.LAZY, cascade = [CascadeType.ALL])
    var pins: MutableSet<Pin> = HashSet(),

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
        var result = name?.hashCode() ?: 0
        result = 31 * result + (groupAdmin?.hashCode() ?: 0)
        result = 31 * result + (description?.hashCode() ?: 0)
        result = 31 * result + (inviteUrl?.hashCode() ?: 0)
        result = 31 * result + (link?.hashCode() ?: 0)
        result = 31 * result + visibility
        result = 31 * result + members.hashCode()
        result = 31 * result + pins.hashCode()
        result = 31 * result + (creationDate?.hashCode() ?: 0)
        result = 31 * result + (updateDate?.hashCode() ?: 0)
        result = 31 * result + isDeleted.hashCode()
        result = 31 * result + (dataSource?.hashCode() ?: 0)
        return result
    }

}