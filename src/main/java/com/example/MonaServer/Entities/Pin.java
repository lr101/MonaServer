package com.example.MonaServer.Entities;

import javax.persistence.*;
import java.util.Date;

@Entity(name = "pins")
public class Pin {

    @Column(name = "id", nullable = false)
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    @Column(name = "latitude", nullable = false)
    private double latitude;

    @Column(name = "longitude", nullable = false)
    private double longitude;

    @Column(name = "creation_date", nullable = false)
    private Date creationDate;

    @ManyToOne
    @JoinColumn(name="type", nullable = false, referencedColumnName = "id")
    private StickerType type;

    public Pin (double latitude, double longitude, Date creationDate, StickerType type) {
        this.latitude = latitude;
        this.longitude = longitude;
        this.creationDate = creationDate;
        this.type = type;
    }

    public Pin(){}

    public StickerType getType() {
        return type;
    }

    public void setType(StickerType type) {
        this.type = type;
    }

    public Date getCreationDate() {
        return creationDate;
    }

    public void setCreationDate(Date creationDate) {
        this.creationDate = creationDate;
    }

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public double getLatitude() {
        return latitude;
    }

    public void setLatitude(double latitude) {
        this.latitude = latitude;
    }

    public double getLongitude() {
        return longitude;
    }

    public void setLongitude(double longitude) {
        this.longitude = longitude;
    }
}
