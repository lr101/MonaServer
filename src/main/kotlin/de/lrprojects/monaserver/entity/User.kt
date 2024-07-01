package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.Min
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import org.hibernate.validator.constraints.Length
import java.util.*

@Entity
@Table(name = "users")
data class User (

    @Id
    @GeneratedValue
    @Column(name = "id", nullable = false)
    var id: UUID? = null,

    @Column(name = "username", unique = true)
    var username: @Min(1) String,

    @Column(name = "password")
    var password: @Min(1) String,

    @Email
    @Column(name = "email")
    var email: String? = null,

    @Column(name = "reset_password_url", unique = true)
    @Basic(fetch = FetchType.LAZY)
    var resetPasswordUrl: String? = null,


    @Basic(fetch=FetchType.LAZY)
    @Column(name = "profile_picture", columnDefinition = "bytea")
    var profilePicture: ByteArray? = null,

    @Column(name = "profile_picture_small", columnDefinition = "bytea")
    @Basic(fetch = FetchType.LAZY)
    var profilePictureSmall: ByteArray? = null,

    @Column(name = "code")
    @Basic(fetch = FetchType.LAZY)
    @Length(min = 6, max = 6)
    var code: String? = null,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "creation_date")
    var createDate: Date? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "update_date")
    var updateDate: Date? = null,

    @OneToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JoinColumn(name = "user_id")
    var refreshTokens: List<RefreshToken> = emptyList(),

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE])
    @JoinTable(
        name = "members",
        joinColumns = [JoinColumn(name = "user_id")],
        inverseJoinColumns = [JoinColumn(name = "group_id")]
    )
    var groups: MutableSet<Group> = mutableSetOf()

) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as User

        if (id != other.id) return false
        if (username != other.username) return false
        if (password != other.password) return false
        if (email != other.email) return false
        if (resetPasswordUrl != other.resetPasswordUrl) return false
        if (profilePicture != null) {
            if (other.profilePicture == null) return false
            if (!profilePicture.contentEquals(other.profilePicture)) return false
        } else if (other.profilePicture != null) return false
        if (profilePictureSmall != null) {
            if (other.profilePictureSmall == null) return false
            if (!profilePictureSmall.contentEquals(other.profilePictureSmall)) return false
        } else if (other.profilePictureSmall != null) return false
        if (code != other.code) return false
        if (createDate != other.createDate) return false
        if (updateDate != other.updateDate) return false
        if (groups != other.groups) return false

        return true
    }

    override fun hashCode(): Int {
        var result = id?.hashCode() ?: 0
        result = 31 * result + (username.hashCode() ?: 0)
        result = 31 * result + (password.hashCode() ?: 0)
        result = 31 * result + (email?.hashCode() ?: 0)
        result = 31 * result + (resetPasswordUrl?.hashCode() ?: 0)
        result = 31 * result + (profilePicture?.contentHashCode() ?: 0)
        result = 31 * result + (profilePictureSmall?.contentHashCode() ?: 0)
        result = 31 * result + (code?.hashCode() ?: 0)
        result = 31 * result + (createDate?.hashCode() ?: 0)
        result = 31 * result + (updateDate?.hashCode() ?: 0)
        result = 31 * result + groups.hashCode()
        return result
    }
}