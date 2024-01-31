package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonProperty
import jakarta.persistence.*
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.Pattern
import org.hibernate.validator.constraints.Length

@Entity
@Table(name = "users")
open class User {
    @Id
    @Column(name = "username", nullable = false)
    open var username: @Min(1) String? = null

    //TODO add nullable = false when possible
    @Column(name = "password")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Basic(fetch = FetchType.LAZY)
    open var password: @Min(1) String? = null

    //TODO add nullable = false when possible
    @Column(name = "email")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Basic(fetch = FetchType.LAZY)
    open var email: @Pattern(regexp = "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$") String? =
        null

    //TODO add nullable = false when possible
    @Column(name = "token", unique = true, length = 500)
    open var token: String? = null

    @Column(name = "reset_password_url", unique = true)
    @Basic(fetch = FetchType.LAZY)
    open var resetPasswordUrl: String? = null

    @Column(name = "profile_picture", columnDefinition = "OID")
    open var profilePicture: Long? = null

    @Column(name = "profile_picture_small", columnDefinition = "bytea")
    @Basic(fetch = FetchType.LAZY)
    open var profilePictureSmall: ByteArray? = null

    @Column(name = "code")
    @Basic(fetch = FetchType.LAZY)
    @Length(min = 6, max = 6)
    open var code: String? = null

}