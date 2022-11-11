package com.example.MonaServer.Entities;

import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;

@Entity(name = "types")
@Getter
@Setter
public class StickerType {
    @Id
    @Column(name = "id", nullable = false)
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "type_id_generator")
    @SequenceGenerator(name="type_id_generator", sequenceName = "type_id_seq")
    private Long id;

    @Column(name="name", nullable = false)
    private String name;

    //TODO add nullable = false when possible
    @Column(name = "icon", columnDefinition="bytea")
    @Lazy
    private byte[] icon = new byte[0];

    @ManyToOne
    @JoinColumn(name = "group_id", referencedColumnName = "id", nullable = false)
    private Group group;

    public StickerType(){};

    public StickerType(String name, byte[] icon, Group group) {
        this.name = name;
        this.icon = icon;
        this.group = group;
    }

}
