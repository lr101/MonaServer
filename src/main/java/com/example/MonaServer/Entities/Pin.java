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
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "pins_id_generator")
    @SequenceGenerator(name="pins_id_generator", sequenceName = "pins_id_seq", allocationSize = 1)
    private Long id;

    @Column(name = "latitude", nullable = false)
    private double latitude;

    @Column(name = "longitude", nullable = false)
    private double longitude;

    @Column(name = "creation_date", nullable = false)
    private Date creationDate;

    @OneToOne
    @JoinColumn(name="creation_user", referencedColumnName = "username")
    private User user;

    public Pin (double latitude, double longitude, Date creationDate, User user) {
        this.latitude = latitude;
        this.longitude = longitude;
        this.creationDate = creationDate;
        this.user = user;
    }

    public Pin(){}

}
