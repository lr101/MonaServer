package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.config.DbConstants.BYTEA
import de.lrprojects.monaserver.config.DbConstants.USERS
import de.lrprojects.monaserver.helper.DeletedEntityType
import de.lrprojects.monaserver.helper.PreDeleteEntity
import jakarta.persistence.*
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.Min
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import org.hibernate.validator.constraints.Length
import java.util.*
import javax.sql.DataSource

@Entity
@Table(name = USERS)
data class User (

    @Column(unique = true)
    var username: @Min(1) String,

    @Column(nullable = false)
    var password: @Min(1) String,

    @Email
    @Column
    var email: String? = null,

    @Column(unique = true)
    @Basic(fetch = FetchType.LAZY)
    var resetPasswordUrl: String? = null,

    @Basic(fetch=FetchType.LAZY)
    @Column(columnDefinition = BYTEA)
    var profilePicture: ByteArray? = null,

    @Column(columnDefinition = BYTEA)
    @Basic(fetch = FetchType.LAZY)
    var profilePictureSmall: ByteArray? = null,

    @Column
    @Basic(fetch = FetchType.LAZY)
    @Length(min = 6, max = 6)
    var code: String? = null,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(nullable = false)
    var creationDate: Date? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
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
    var groups: MutableSet<Group> = mutableSetOf(),

    @Transient
    private var dataSource: DataSource? = null

): PreDeleteEntity() {
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
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false
        if (groups != other.groups) return false

        return true
    }

    override fun hashCode(): Int {
        var result = id?.hashCode() ?: 0
        result = 31 * result + username.hashCode()
        result = 31 * result + password.hashCode()
        result = 31 * result + (email?.hashCode() ?: 0)
        result = 31 * result + (resetPasswordUrl?.hashCode() ?: 0)
        result = 31 * result + (profilePicture?.contentHashCode() ?: 0)
        result = 31 * result + (profilePictureSmall?.contentHashCode() ?: 0)
        result = 31 * result + (code?.hashCode() ?: 0)
        result = 31 * result + (creationDate?.hashCode() ?: 0)
        result = 31 * result + (updateDate?.hashCode() ?: 0)
        result = 31 * result + groups.hashCode()
        return result
    }

    override fun getDeletedEntityType() = DeletedEntityType.USER
}