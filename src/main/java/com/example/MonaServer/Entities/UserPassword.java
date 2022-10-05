package com.example.MonaServer.Entities;

import com.example.MonaServer.Helper.JWTUtil;
import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.UserDetails;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import java.util.Collection;
import java.util.Collections;
import java.util.Random;

@Entity
public class UserPassword  {

    @Id
    @Column(name = "username", nullable = false)
    String username;

    @Column(name = "password", nullable = false)
    //@JsonProperty(access = JsonProperty.Access.WRITE_ONLY) //prevents the password field from being included in the JSON response TODO
    String password;

    @Column(name = "email")
    String email;

    @Column(name = "token", unique = true)
    String token;

    public UserPassword(String username, String password, String email) {
        this.username = username;
        this.password = password;
        this.email = email;
        JWTUtil jwtUtil = new JWTUtil();
        this.token = jwtUtil.generateToken(username);
    }

    public UserPassword() {}

    public String getUsername() {
        return username;
    }


    public void setUsername(String username) {
        this.username = username;
    }
    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getToken() {
        return token;
    }

    public void setToken(String token) {
        this.token = token;
    }
}
