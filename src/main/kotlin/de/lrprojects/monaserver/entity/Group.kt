package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.helper.ImageHelper
import de.lrprojects.monaserver.helper.SecurityHelper
import jakarta.persistence.*
import lombok.Getter
import lombok.Setter
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction
import org.openapitools.model.Pin
import java.util.function.Predicate

@Entity(name = "groups")
@Getter
@Setter
class Group() {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "group_id_generator")
    @SequenceGenerator(name = "group_id_generator", sequenceName = "group_id_seq", allocationSize = 1)
    @Column(name = "group_id", nullable = false)
    private val groupId: Long? = null

    @Column(name = "name", nullable = false, unique = true)
    private var name: String? = null

    @OneToOne
    @JoinColumn(name = "group_admin", nullable = false, referencedColumnName = "username")
    private var groupAdmin: User? = null

    @Column(name = "description")
    @Basic(fetch = FetchType.LAZY)
    private var description: String? = null

    @Lob
    @Column(name = "profile_image", nullable = false)
    private lateinit var profileImage: ByteArray

    @Column(name = "pin_image", nullable = false)
    @Basic(fetch = FetchType.LAZY)
    private lateinit var pinImage: ByteArray

    @Column(name = "invite_url", unique = true)
    private var inviteUrl: String? = null

    //TODO somthing like:
    // 0: public
    // 1 : private visible
    // 2 : private only invite
    @Column(name = "visibility", nullable = false)
    private var visibility = 0

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], targetEntity = User::class)
    @JoinTable(
        name = "members",
        joinColumns = [JoinColumn(name = "group_id")],
        inverseJoinColumns = [JoinColumn(name = "username")]
    )
    @OnDelete(action = OnDeleteAction.CASCADE)
    private val members: MutableSet<User> = HashSet<User>()

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], targetEntity = Pin::class)
    @JoinTable(
        name = "groups_pins",
        joinColumns = [JoinColumn(name = "group_id")],
        inverseJoinColumns = [JoinColumn(name = "id")]
    )
    @OnDelete(action = OnDeleteAction.CASCADE)
    private val pins: MutableSet<Pin> = HashSet()

    fun addGroupMember(user: User) {
        members.add(user)
    }

    fun addPin(pin: Pin) {
        pins.add(pin)
    }

    fun removeGroupMember(username: String?) {
        members.removeIf(Predicate<User> { e: User -> e.username.equals(username) })
    }

    fun updateGroupImage(image: ByteArray?) {
        if (image != null) {
            profileImage = ImageHelper.getProfileImage(image)
            pinImage = ImageHelper.getPinImage(image)
        }
    }

    fun setInvite() {
        inviteUrl = if (visibility != 0) {
            SecurityHelper.generateAlphabeticRandomString(10)
        } else {
            null
        }
    }
}