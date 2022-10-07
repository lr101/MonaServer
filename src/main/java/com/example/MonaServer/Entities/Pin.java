package com.example.MonaServer.Entities;

import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import javax.persistence.*;
import java.util.Date;

@Entity(name = "pins")
@Getter
@Setter
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
    @OnDelete(action= OnDeleteAction.CASCADE)
    private StickerType type;

    @OneToOne
    @JoinColumn(name="creation_user", referencedColumnName = "username")
    private User user;

    public Pin (double latitude, double longitude, Date creationDate, StickerType type, User user) {
        this.latitude = latitude;
        this.longitude = longitude;
        this.creationDate = creationDate;
        this.type = type;
        this.user = user;
    }

    public Pin(){}

}
