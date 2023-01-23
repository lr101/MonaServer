package com.example.MonaServer.Entities;

import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.*;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;
import javax.persistence.Entity;
import javax.transaction.Transactional;

@Entity(name = "monas")
@Getter
@Setter
public class Mona {

    @Column(name = "image", nullable = false)
    @Lob
    private byte[] image = new byte[0];

    @OneToOne
    @OnDelete(action= OnDeleteAction.CASCADE)
    @JoinColumn(name = "pin", nullable = false, referencedColumnName = "id")
    private Pin pin;

    @Id
    @Column(name = "id", nullable = false)
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "mona_id_generator")
    @SequenceGenerator(name="mona_id_generator", sequenceName = "mona_id_seq", allocationSize = 1)
    private Long id;

    public Mona(byte[] image, Pin pin) {
        this.image = image;
        this.pin = pin;
    }

    public Mona() {};

}
