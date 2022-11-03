package com.example.MonaServer.Entities;

import lombok.Getter;
import lombok.Setter;
import javax.persistence.*;
import java.util.Set;

@Entity(name = "groups")
@Getter
@Setter
public class Group {
    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    @Column(name = "id", nullable = false)
    private Long id;

    @Column(name = "name", nullable = false, unique = true)
    private String name;

    @OneToOne
    @JoinColumn(name = "group_admin", nullable = false, referencedColumnName = "username")
    private User groupAdmin;

    @Column(name = "description")
    private String description;

    @Column(name = "profile_image")
    private byte[] profileImage;

    @Column(name = "invite_url")
    private String inviteUrl;

    //TODO somthing like:
    // 0: public
    // 1 : private visible
    // 2 : private only invite
    @Column(name = "visibility", nullable = false)
    private int visibility;

    @ManyToMany
    @JoinTable(
            name = "members",
            joinColumns = { @JoinColumn(name = "username") },
            inverseJoinColumns = { @JoinColumn(name = "id") }
    )
    private Set<User> members;

    @OneToMany(mappedBy = "id")
    private Set<StickerType> stickerTypes;

    public Group(Long id, String name, User groupAdmin, int visibility) {
        this.id = id;
        this.name = name;
        this.groupAdmin = groupAdmin;
        this.visibility = visibility;
    }

    public Group() {}
}
