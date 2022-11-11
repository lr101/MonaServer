package com.example.MonaServer.Entities;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Helper.SecurityFilter;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;

import javax.persistence.*;
import java.util.HashSet;
import java.util.Set;

@Entity(name = "groups")
@Getter
@Setter
public class Group {
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "group_id_generator")
    @SequenceGenerator(name="group_id_generator", sequenceName = "group_id_seq")
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

    @Column(name = "invite_url", unique = true)
    private String inviteUrl;

    //TODO somthing like:
    // 0: public
    // 1 : private visible
    // 2 : private only invite
    @Column(name = "visibility", nullable = false)
    private int visibility;

    @ManyToMany(fetch = FetchType.LAZY,
            cascade =
                    {
                            CascadeType.DETACH,
                            CascadeType.MERGE,
                            CascadeType.REFRESH,
                            CascadeType.PERSIST
                    },
            targetEntity = User.class)
    @JoinTable(
            name = "members",
            joinColumns = { @JoinColumn(name = "id") },
            inverseJoinColumns = { @JoinColumn(name = "username") }
    )
    @OnDelete(action= OnDeleteAction.CASCADE)
    private Set<User> members = new HashSet<>();

    public Group(String name, User groupAdmin, int visibility, String description, byte[] profileImage) {
        this.name = name;
        this.groupAdmin = groupAdmin;
        this.visibility = visibility;
        this.description = description;
        this.profileImage = profileImage;
        if (visibility != 0) {
            inviteUrl = SecurityFilter.generateAlphabeticRandomString(10);
        }
        this.members.add(groupAdmin);
    }

    public Group(GroupDTO groupDTO, User groupAdmin) {
        this.name = groupDTO.getName();
        this.groupAdmin = groupAdmin;
        this.visibility = groupDTO.getVisibility();
        this.description = groupDTO.getDescription();
        this.profileImage = groupDTO.getProfileImage();
        if (visibility != 0) {
            inviteUrl = SecurityFilter.generateAlphabeticRandomString(10);
        }
        this.members.add(groupAdmin);
    }

    public Group() {}

    public void addGroupMember(User user) {
        members.add(user);
    }

    public void setInvite() {
        if (visibility != 0) {
            inviteUrl = SecurityFilter.generateAlphabeticRandomString(10);
        } else {
            inviteUrl = null;
        }
    }

}
