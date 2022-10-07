package com.example.MonaServer.Entities;

import javax.persistence.*;
import java.util.Date;

@Entity(name = "versions")
public class Versioning {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "id", nullable = false)
    private Long id;

    @Column(name = "pin_id", nullable = false)
    private Long pinId;

    @Column(name = "date", nullable = false)
    private Date date;

    /**
     * type: 0 -> Pin with {pinId} is newly added
     * type: 1 -> Pin with {pinId} is deleted
     */
    @Column(name = "type", nullable = false)
    private int type;


    public Versioning() {}

    public Versioning(Long pinId, int type, Date date) {
        this.pinId = pinId;
        this.type = type;
        this.date = date;
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

    public Date getDate() {
        return date;
    }

    public void setDate(Date date) {
        this.date = date;
    }
}

