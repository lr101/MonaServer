package com.example.MonaServer.Entities;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;

@Entity(name = "versions")
public class Versioning {
    @Id
    @Column(name = "id", nullable = false)
    private Long id;

    @Column(name = "pin_id", nullable = false)
    private Long pinId;

    /**
     * type: 0 -> Pin with {pinId} is newly added
     * type: 1 -> Pin with {pinId} is deleted
     */
    @Column(name = "type", nullable = false)
    private int type;


    public Versioning() {}

    public Versioning(Long id, Long pinId, int type) {
        this.id = id;
        this.pinId = pinId;
        this.type = type;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getPinId() {
        return pinId;
    }

    public int getType() {
        return type;
    }

    public void setType(int type) {
        this.type = type;
    }

    public void setPinId(Long pinId) {
        this.pinId = pinId;
    }
}

