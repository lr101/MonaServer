package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.helper.SecurityHelper
import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction
import org.hibernate.annotations.UpdateTimestamp
import java.util.*


@Entity
@Table(name = "groups")
open class Group {

    @Id
    @GeneratedValue
    @Column(name = "id", nullable = false)
    open var id: UUID? = null

    @Column(name = "name", nullable = false, unique = true)
    open var name: String? = null

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "admin_id", referencedColumnName = "id")
    open var groupAdmin: User? = null

    @Column(name = "description")
    @Basic(fetch = FetchType.LAZY)
    open var description: String? = null

    @Column(name = "group_profile", nullable = false, columnDefinition = "bytea")
    @Basic(fetch = FetchType.LAZY)
    open var profileImage: ByteArray? = null

    @Column(name = "pin_image", nullable = false, columnDefinition = "bytea")
    @Basic(fetch = FetchType.LAZY)
    open var pinImage: ByteArray? = null

    @Column(name = "invite_url", unique = true)
    open var inviteUrl: String? = null

    @Column(name = "link")
    open var link: String? = null

    @Column(name = "visibility", nullable = false)
    open var visibility = 0

    @ManyToMany(mappedBy = "groups", fetch = FetchType.LAZY)
    open var members: MutableSet<User> = mutableSetOf()

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], targetEntity = Pin::class)
    @JoinTable(
        name = "groups_pins",
        joinColumns = [JoinColumn(name = "group_id")],
        inverseJoinColumns = [JoinColumn(name = "pin_id")]
    )
    @OnDelete(action = OnDeleteAction.CASCADE)
    open var pins: MutableSet<Pin> = HashSet()


    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "creation_date")
    open var createDate: Date? = null

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "update_date")
    open var updateDate: Date? = null

    @Column(name = "is_deleted", nullable = false)
    open var isDeleted: Boolean = false


    fun setInvite() {
        inviteUrl = if (visibility != 0) {
            SecurityHelper.generateAlphabeticRandomString(10)
        } else {
            null
        }
    }
}