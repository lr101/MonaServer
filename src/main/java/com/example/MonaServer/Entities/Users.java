package com.example.MonaServer.Entities;

import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import javax.persistence.*;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Entity(name = "users")
public class Users {

    @Id
    @Column(name = "username", nullable = false)
    private String username;

    @ManyToMany
    @JoinTable(
            name = "found_pins",
            joinColumns = { @JoinColumn(name = "username") },
            inverseJoinColumns = { @JoinColumn(name = "id") }
    )
    @OnDelete(action= OnDeleteAction.CASCADE)
    private Set<Pin> foundPins = new HashSet<>();

    @ManyToMany
    @JoinTable(
            name = "created_pins",
            joinColumns = { @JoinColumn(name = "username") },
            inverseJoinColumns = { @JoinColumn(name = "id") }
    )
    @OnDelete(action= OnDeleteAction.CASCADE)
    private Set<Pin> createdPins = new HashSet<>();

    @Column(name = "points")
    private int points;

    public Users() {}

    public Users(String username) {
        this.username = username;
    }

    public Set<Pin> getFoundPins() {
        return foundPins;
    }

    public void setFoundPins(Set<Pin> foundPins) {
        this.foundPins = foundPins;
    }

    public Set<Pin> getCreatedPins() {
        return createdPins;
    }

    public void setCreatedPins(Set<Pin> created_pins) {
        this.createdPins = created_pins;
    }

    public String getUsername() {
        return username;
    }

    public void setUsername(String username) {
        this.username = username;
    }

    public int getPoints() {
        return points;
    }

    public void setPoints(int points) {
        this.points = points;
    }

    public void addPoints(int points) {
        this.points += points;
    }
}
