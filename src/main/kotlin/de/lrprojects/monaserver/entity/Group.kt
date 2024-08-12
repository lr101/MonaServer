package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.config.DbConstants.ADMIN_ID
import de.lrprojects.monaserver.config.DbConstants.BYTEA
import de.lrprojects.monaserver.config.DbConstants.GROUPS
import de.lrprojects.monaserver.config.DbConstants.ID
import de.lrprojects.monaserver.helper.SecurityHelper
import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import java.util.*


@Entity
@Table(name = GROUPS)
class Group {

    @Id
    @GeneratedValue
    @Column(nullable = false)
    var id: UUID? = null

    @Column(nullable = false, unique = true)
    var name: String? = null

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = ADMIN_ID, referencedColumnName = ID)
    var groupAdmin: User? = null

    @Column
    var description: String? = null

    @Column(nullable = false, columnDefinition = BYTEA)
    @Basic(fetch = FetchType.LAZY)
    var groupProfile: ByteArray? = null

    @Column(nullable = false, columnDefinition = BYTEA)
    @Basic(fetch = FetchType.LAZY)
    var pinImage: ByteArray? = null

    @Column(unique = true)
    var inviteUrl: String? = null

    @Column
    var link: String? = null

    @Column(nullable = false)
    var visibility = 0

    @ManyToMany(mappedBy = GROUPS, fetch = FetchType.LAZY)
    var members: MutableSet<User> = mutableSetOf()

    @OneToMany(mappedBy = ID, fetch = FetchType.LAZY, cascade = [CascadeType.ALL])
    var pins: MutableSet<Pin> = HashSet()

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var creationDate: Date? = null

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: Date? = null

    @Column(nullable = false)
    var isDeleted: Boolean = false


    fun setInvite() {
        inviteUrl = if (visibility != 0) {
            SecurityHelper.generateAlphabeticRandomString(10)
        } else {
            null
        }
    }

}