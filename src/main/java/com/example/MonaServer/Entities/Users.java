package com.example.MonaServer.Entities;

import javax.persistence.*;
import java.util.ArrayList;
import java.util.List;

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
    private List<Pin> foundPins = new ArrayList<>();

    @ManyToMany
    @JoinTable(
            name = "created_pins",
            joinColumns = { @JoinColumn(name = "username") },
            inverseJoinColumns = { @JoinColumn(name = "id") }
    )
    private List<Pin> createdPins = new ArrayList<>();

    @Column(name = "points")
    private int points;

    public List<Pin> getFoundPins() {
        return foundPins;
    }

    public void setFoundPins(List<Pin> foundPins) {
        this.foundPins = foundPins;
    }

    public List<Pin> getCreatedPins() {
        return createdPins;
    }

    public void setCreatedPins(List<Pin> created_pins) {
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
}
