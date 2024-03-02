package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.helper.SecurityHelper
import jakarta.persistence.*
import jakarta.persistence.CascadeType
import jakarta.persistence.Table
import org.hibernate.annotations.*
import java.util.*


@Entity
@Table(name = "groups")
@SQLDelete(sql = "UPDATE groups SET is_deleted = true WHERE group_id=?")
@SQLRestriction("is_deleted=false")
open class Group {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "group_id_generator")
    @SequenceGenerator(name = "group_id_generator", sequenceName = "group_id_seq", allocationSize = 1)
    @Column(name = "group_id", nullable = false)
    open var groupId: Long? = null

    @Column(name = "name", nullable = false, unique = true)
    open var name: String? = null

    @ManyToOne(fetch = FetchType.EAGER)
    @JoinColumn(name = "admin_id", referencedColumnName = "user_id")
    open var groupAdmin: User? = null

    @Column(name = "description")
    @Basic(fetch = FetchType.LAZY)
    open var description: String? = null

    @Lob
    @Column(name = "profile_image", nullable = false)
    @Basic(fetch = FetchType.LAZY)
    open var profileImage: ByteArray? = null

    @Column(name = "pin_image", nullable = false)
    @Basic(fetch = FetchType.LAZY)
    open var pinImage: ByteArray? = null

    @Column(name = "invite_url", unique = true)
    open var inviteUrl: String? = null

    @Column(name = "link")
    open var link: String? = null


    //TODO somthing like:
    // 0: public
    // 1 : visible
    // 2 : only invite
    @Column(name = "visibility", nullable = false)
    open var visibility = 0

    @ManyToMany(mappedBy = "groups", fetch = FetchType.LAZY)
    open var members: MutableSet<User> = mutableSetOf()

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], targetEntity = Pin::class)
    @JoinTable(
        name = "groups_pins",
        joinColumns = [JoinColumn(name = "group_id")],
        inverseJoinColumns = [JoinColumn(name = "id")]
    )
    @OnDelete(action = OnDeleteAction.CASCADE)
    open var pins: MutableSet<Pin> = HashSet()


    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "creation_date")
    open var createDate: Date? = null

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "last_updated")
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