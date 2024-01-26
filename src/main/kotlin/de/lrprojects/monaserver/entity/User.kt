package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonProperty
import de.lrprojects.monaserver.helper.ImageHelper
import jakarta.persistence.*
import lombok.Getter
import lombok.Setter
import javax.validation.constraints.Min
import javax.validation.constraints.Pattern

@Entity
@Table(name = "users")
class User {
    @Id
    @Column(name = "username", nullable = false)
    var username: @Min(1) String = ""

    //TODO add nullable = false when possible
    @Column(name = "password")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Basic(fetch = FetchType.LAZY)
    var password: @Min(1) String? = null

    //TODO add nullable = false when possible
    @Column(name = "email")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Basic(fetch = FetchType.LAZY)
    var email: @Pattern(regexp = "^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$") String? =
        null

    //TODO add nullable = false when possible
    @Column(name = "token", unique = true, length = 500)
    var token: String? = null

    @Column(name = "reset_password_url", unique = true)
    @Basic(fetch = FetchType.LAZY)
    var resetPasswordUrl: String? = null

    @Lob
    @Column(name = "profile_picture")
    var profilePicture: ByteArray? = null

    @Column(name = "profile_picture_small", columnDefinition = "bytea")
    @Basic(fetch = FetchType.LAZY)
    var profilePictureSmall: ByteArray? = null

    @Column(name = "code")
    @Basic(fetch = FetchType.LAZY)
    var code: Int? = null

}