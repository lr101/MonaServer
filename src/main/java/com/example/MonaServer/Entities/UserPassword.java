package com.example.MonaServer.Entities;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;

@Entity
public class UserPassword {

    @Id
    @Column(name = "username", nullable = false)
    String username;

    @Column(name = "password", nullable = false)
    String password;


    public UserPassword(String username, String password) {
        this.username = username;
        this.password = password;
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
}
