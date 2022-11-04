package com.example.MonaServer.Entities;

import lombok.Getter;
import lombok.Setter;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;

@Entity(name = "types")
@Getter
@Setter
public class StickerType {
    @Id
    @Column(name = "id", nullable = false)
    @GeneratedValue(strategy = GenerationType.SEQUENCE)
    private Long id;

    @Column(name="name", nullable = false)
    private String name;

    //TODO add nullable = false when possible
    @Column(name = "icon", columnDefinition="bytea")
    @Lazy
    private byte[] icon = new byte[0];

    @ManyToOne
    @JoinColumn(name = "id", nullable = false)
    private Group group;

}
