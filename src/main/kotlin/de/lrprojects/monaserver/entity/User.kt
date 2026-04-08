package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.entity.keys.PreDeleteEntity
import de.lrprojects.monaserver.properties.DbConstants.ID
import de.lrprojects.monaserver.properties.DbConstants.MEMBER_USER
import de.lrprojects.monaserver.properties.DbConstants.SELECTED_BATCH
import de.lrprojects.monaserver.properties.DbConstants.USER
import de.lrprojects.monaserver.properties.DbConstants.USERS
import de.lrprojects.monaserver.types.DeletedEntityType
import jakarta.persistence.Basic
import jakarta.persistence.CascadeType
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.FetchType
import jakarta.persistence.JoinColumn
import jakarta.persistence.ManyToOne
import jakarta.persistence.OneToMany
import jakarta.persistence.Table
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

    @param:Email
    @Column
    var email: String? = null,

    @Column
    var description: String? = null,

    @Column
    var lastUsernameUpdate: OffsetDateTime? = null,

    @Column(unique = true)
    var resetPasswordUrl: String? = null,

    @Column
    var resetPasswordExpiration: OffsetDateTime? = null,

    @Column(nullable = false)
    var failedLoginAttempts: Int = 0,

    @Column(nullable = false)
    var profilePictureExists: Boolean = false,

    @Column(nullable = false)
    var emailConfirmed: Boolean = false,

    @Column
    var emailConfirmationUrl: String? = null,

    @Column
    @param:Length(min = 6, max = 6)
    var code: String? = null,

    @Column
    var codeExpiration: OffsetDateTime? = null,

    @Column
    var deletionUrl: String? = null,

    @Column(nullable = false)
    var xp: Int = 0,

    @Column
    var firebaseToken: String? = null,

    @JoinColumn(name = SELECTED_BATCH, referencedColumnName = ID)
    @ManyToOne(fetch = FetchType.EAGER, cascade = [CascadeType.ALL])
    var selectedBatch: UserAchievement? = null,

    @CreationTimestamp
    @Column(nullable = false)
    var creationDate: OffsetDateTime? = null,

    @UpdateTimestamp
    @Column(nullable = false)
    var updateDate: OffsetDateTime? = null,

    @OneToMany(mappedBy = USER, fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    @JsonIgnore
    var refreshTokens: MutableList<RefreshToken> = mutableListOf(),

    @OneToMany(mappedBy = MEMBER_USER, fetch = FetchType.LAZY, cascade = [CascadeType.ALL], orphanRemoval = true)
    @JsonIgnore
    var groups: MutableSet<Member> = mutableSetOf(),


    @OneToMany(mappedBy = USER, fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE], orphanRemoval = true)
    @JsonIgnore
    var seasons: MutableSet<UserSeason> = HashSet(),


    @Transient
    private var dataSource: DataSource? = null,

    ): PreDeleteEntity() {


    override fun getDeletedEntityType() = DeletedEntityType.USER
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is User) return false

        if (id != null && other.id != null) {
            return id == other.id
        }

        return username == other.username &&
                email == other.email
    }

    override fun hashCode(): Int {
        return id?.hashCode() ?: username.hashCode()
    }
}