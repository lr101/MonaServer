package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.entity.keys.PreDeleteEntity
import de.lrprojects.monaserver.helper.SecurityHelper
import de.lrprojects.monaserver.properties.DbConstants.ADMIN_ID
import de.lrprojects.monaserver.properties.DbConstants.GROUP
import de.lrprojects.monaserver.properties.DbConstants.GROUPS
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.MEMBER_GROUP
import de.lrprojects.monaserver.types.DeletedEntityType
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
import jakarta.persistence.Transient
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.time.OffsetDateTime
import java.util.Objects
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

    @OneToMany(mappedBy = GROUP, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var seasons: MutableSet<GroupSeason> = HashSet(),

    @CreationTimestamp
    @Column
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
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
        if (other !is Group) return false

        if (id != null && other.id != null) {
            return id == other.id
        }

        return name == other.name &&
                groupAdmin?.id == other.groupAdmin?.id
    }

    override fun hashCode(): Int {
        return id?.hashCode() ?: name?.hashCode() ?: 0
    }


}
