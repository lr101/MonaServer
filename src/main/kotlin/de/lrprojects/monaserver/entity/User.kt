package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.types.DeletedEntityType
import de.lrprojects.monaserver.entity.keys.PreDeleteEntity
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.MEMBER_USER
import de.lrprojects.monaserver.properties.DbConstants.SELECTED_BATCH
import de.lrprojects.monaserver.properties.DbConstants.USER
import de.lrprojects.monaserver.properties.DbConstants.USERS
import de.lrprojects.monaserver.properties.DbConstants.USER_ID
import jakarta.persistence.Basic
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

    @Column
    var description: String? = null,

    @Column
    var lastUsernameUpdate: OffsetDateTime? = null,

    @Column(unique = true)
    var resetPasswordUrl: String? = null,

    @Column
    @CreationTimestamp
    var resetPasswordExpiration: OffsetDateTime? = null,

    @Column
    var failedLoginAttempts: Int = 0,

    @Column
    var profilePictureExists: Boolean = false,

    @Column
    var emailConfirmed: Boolean = false,

    @Column
    var emailConfirmationUrl: String? = null,

    @Column
    @Length(min = 6, max = 6)
    var code: String? = null,

    @Column
    @Basic(fetch = FetchType.LAZY)
    var codeExpiration: OffsetDateTime? = null,

    @Column
    var deletionUrl: String? = null,

    @Column
    var xp: Int = 0,

    @JoinColumn(name = SELECTED_BATCH, referencedColumnName = ID)
    @ManyToOne(fetch = FetchType.EAGER, cascade = [CascadeType.ALL])
    var selectedBatch: UserAchievement? = null,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(nullable = false)
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: OffsetDateTime? = null,

    @OneToMany(mappedBy = USER, fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    @JsonIgnore
    var refreshTokens: List<RefreshToken> = emptyList(),

    @OneToMany(mappedBy = MEMBER_USER, fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    @JsonIgnore
    var groups: MutableSet<Member> = mutableSetOf(),


    @OneToMany(mappedBy = USER_ID, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var seasons: MutableSet<UserSeason> = HashSet(),


    @Transient
    private var dataSource: DataSource? = null

): PreDeleteEntity() {


    override fun getDeletedEntityType() = DeletedEntityType.USER
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (javaClass != other?.javaClass) return false

        other as User

        if (username != other.username) return false
        if (password != other.password) return false
        if (email != other.email) return false
        if (description != other.description) return false
        if (lastUsernameUpdate != other.lastUsernameUpdate) return false
        if (resetPasswordUrl != other.resetPasswordUrl) return false
        if (resetPasswordExpiration != other.resetPasswordExpiration) return false
        if (failedLoginAttempts != other.failedLoginAttempts) return false
        if (profilePictureExists != other.profilePictureExists) return false
        if (code != other.code) return false
        if (codeExpiration != other.codeExpiration) return false
        if (deletionUrl != other.deletionUrl) return false
        if (xp != other.xp) return false
        if (selectedBatch != other.selectedBatch) return false
        if (creationDate != other.creationDate) return false
        if (updateDate != other.updateDate) return false
        if (refreshTokens != other.refreshTokens) return false
        if (groups != other.groups) return false
        if (dataSource != other.dataSource) return false

        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }
}