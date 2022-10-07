package com.example.MonaServer.Entities;

import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;
import javax.transaction.Transactional;

@Entity(name = "monas")
@Getter
@Setter
public class Mona {

    @Column(name = "image", columnDefinition="bytea", nullable = false)
    @Lazy
    private byte[] image = new byte[0];

    @OneToOne
    @OnDelete(action= OnDeleteAction.CASCADE)
    @JoinColumn(name = "pin", nullable = false, referencedColumnName = "id")
    private Pin pin;

    @Id
    @Column(name = "id", nullable = false)
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    public Mona(byte[] image, Pin pin) {
        this.image = image;
        this.pin = pin;
    }

    public Mona() {};

}
