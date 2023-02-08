package com.example.MonaServer.Entities;

import com.example.MonaServer.Helper.ImageHelper;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.*;
import org.hibernate.validator.constraints.NotBlank;
import org.hibernate.validator.constraints.NotEmpty;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;
import javax.persistence.Entity;
import javax.validation.Valid;
import javax.validation.constraints.Min;
import javax.validation.constraints.Pattern;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity(name = "users")
@Getter
@Setter
public class User {

    @Id
    @Column(name = "username", nullable = false)
    @Min(1)
    private String username;

    //TODO add nullable = false when possible
    @Column(name = "password")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Min(1)
    @Basic(fetch=FetchType.LAZY)
    String password;

    //TODO add nullable = false when possible
    @Column(name = "email")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Basic(fetch=FetchType.LAZY)
    @Pattern(regexp="^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$")
    String email;

    //TODO add nullable = false when possible
    @Column(name = "token", unique = true, length = 500)
    String token;

    @Column(name = "reset_password_url", unique = true)
    @Basic(fetch=FetchType.LAZY)
    String resetPasswordUrl;

    @Lob
    @Column(name = "profile_picture")
    private byte[] profilePicture = new byte[0];

    @Column(name = "profile_picture_small", columnDefinition="bytea")
    @Basic(fetch=FetchType.LAZY)
    private byte[] profilePictureSmall = new byte[0];

    public User() {}

    public User(String username, String password, String email, String token, byte[] profilePicture) {
        this.username = username;
        this.password = password;
        this.email = email;
        this.token = token;
        if (profilePicture != null) {
            this.profilePicture = ImageHelper.getProfileImage(profilePicture);
            this.profilePictureSmall = ImageHelper.getProfileImageSmall(profilePicture);
        }
    }
}
