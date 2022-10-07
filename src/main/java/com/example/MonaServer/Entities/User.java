package com.example.MonaServer.Entities;

import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.hibernate.validator.constraints.NotBlank;
import org.hibernate.validator.constraints.NotEmpty;

import javax.persistence.*;
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
    String password;

    //TODO add nullable = false when possible
    @Column(name = "email")
    @JsonProperty(access = JsonProperty.Access.WRITE_ONLY)
    @Pattern(regexp="^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$")
    String email;

    //TODO add nullable = false when possible
    @Column(name = "token", unique = true)
    String token;

    public User() {}

    public User(String username, String password, String email, String token) {
        this.username = username;
        this.password = password;
        this.email = email;
        this.token = token;
    }
}
