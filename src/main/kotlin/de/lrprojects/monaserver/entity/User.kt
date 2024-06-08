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
open class User {

    @Id
    @GeneratedValue
    @Column(name = "id", nullable = false)
    open var id: UUID? = null

    @Column(name = "username", unique = true)
    open var username: @Min(1) String? = null

    @Column(name = "password")
    open var password: @Min(1) String? = null

    @Email
    @Column(name = "email")
    open var email: String? = null

    //TODO add nullable = false when possible
    @Column(name = "token", unique = true, length = 500)
    open var token: String? = null

    @Column(name = "reset_password_url", unique = true)
    @Basic(fetch = FetchType.LAZY)
    open var resetPasswordUrl: String? = null

    @Lob
    @Basic(fetch=FetchType.LAZY)
    @Column(name = "profile_picture")
    open var profilePicture: ByteArray? = null

    @Column(name = "profile_picture_small", columnDefinition = "bytea")
    @Basic(fetch = FetchType.LAZY)
    open var profilePictureSmall: ByteArray? = null

    @Column(name = "code")
    @Basic(fetch = FetchType.LAZY)
    @Length(min = 6, max = 6)
    open var code: String? = null

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "creation_date")
    open var createDate: Date? = null

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "update_date")
    open var updateDate: Date? = null

    @ManyToMany(fetch = FetchType.LAZY, cascade = [CascadeType.REMOVE])
    @JoinTable(
        name = "members",
        joinColumns = [JoinColumn(name = "user_id")],
        inverseJoinColumns = [JoinColumn(name = "group_id")]
    )
    open var groups: MutableSet<Group> = mutableSetOf()

}