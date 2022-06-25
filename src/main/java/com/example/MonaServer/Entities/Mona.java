package com.example.MonaServer.Entities;

import javax.persistence.*;

@Entity(name = "monas")
public class Mona {

    @Column(name = "image", columnDefinition="bytea")
    private byte[] image = new byte[0];

    @OneToOne
    @JoinColumn(name = "pin", nullable = false, referencedColumnName = "id")
    private Pin pin;

    @Id
    @Column(name = "id", nullable = false)
    @GeneratedValue(strategy = GenerationType.AUTO)
    private Long id;

    public Mona (byte[] image, Pin pin) {
        this.image = image;
        this.pin = pin;
    }

    public Mona(){}

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public byte[] getImage() {
        return image;
    }

    public void setImage(byte[] image) {
        this.image = image;
    }

    public Pin getPin() {
        return pin;
    }

    public void setPin(Pin pin) {
        this.pin = pin;
    }
}
