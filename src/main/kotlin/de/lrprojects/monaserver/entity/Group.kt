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
open class Group() {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "group_id_generator")
    @SequenceGenerator(name = "group_id_generator", sequenceName = "group_id_seq", allocationSize = 1)
    @Column(name = "group_id", nullable = false)
    open var groupId: Long? = null

    @Column(name = "name", nullable = false, unique = true)
    open var name: String? = null

    @OneToOne
    @JoinColumn(name = "group_admin", nullable = false, referencedColumnName = "username")
    open var groupAdmin: User? = null

    @Column(name = "description")
    @Basic(fetch = FetchType.LAZY)
    open var description: String? = null

    @Column(name = "profile_image", nullable = false, columnDefinition = "OID")
    open var profileImage: Long? = null

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

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], targetEntity = User::class)
    @JoinTable(
        name = "members",
        joinColumns = [JoinColumn(name = "group_id")],
        inverseJoinColumns = [JoinColumn(name = "username")]
    )
    @OnDelete(action = OnDeleteAction.CASCADE)
    open var members: MutableSet<User> = HashSet<User>()

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


    fun setInvite() {
        inviteUrl = if (visibility != 0) {
            SecurityHelper.generateAlphabeticRandomString(10)
        } else {
            null
        }
    }
}