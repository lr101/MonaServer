package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.helper.DeletedEntityType
import de.lrprojects.monaserver.helper.PreDeleteEntity
import de.lrprojects.monaserver.properties.DbConstants.USERS
import jakarta.persistence.Basic
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import jakarta.persistence.Transient
import jakarta.validation.constraints.Email
import jakarta.validation.constraints.Min
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.UpdateTimestamp
import org.hibernate.validator.constraints.Length
import java.time.OffsetDateTime
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

    @Column
    @CreationTimestamp
    @Basic(fetch = FetchType.LAZY)
    var resetPasswordExpiration: OffsetDateTime? = null,

    @Column
    var failedLoginAttempts: Int = 0,

    @Column
    var profilePictureExists: Boolean = false,

    @Column
    @Basic(fetch = FetchType.LAZY)
    @Length(min = 6, max = 6)
    var code: String? = null,

    @Column
    @Basic(fetch = FetchType.LAZY)
    var codeExpiration: OffsetDateTime? = null,

    @Column
    var deletionUrl: String? = null,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(nullable = false)
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: OffsetDateTime? = null,

    @OneToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JoinColumn(name = "user_id")
    @JsonIgnore
    var refreshTokens: List<RefreshToken> = emptyList(),

    @OneToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JoinColumn(name = "user_id")
    @JsonIgnore
    var groups: MutableSet<Member> = mutableSetOf(),

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
        if (profilePictureExists != other.profilePictureExists) return false
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
        result = 31 * result + (profilePictureExists.hashCode())
        result = 31 * result + (code?.hashCode() ?: 0)
        result = 31 * result + (creationDate?.hashCode() ?: 0)
        result = 31 * result + (updateDate?.hashCode() ?: 0)
        result = 31 * result + groups.hashCode()
        return result
    }

    override fun getDeletedEntityType() = DeletedEntityType.USER
}