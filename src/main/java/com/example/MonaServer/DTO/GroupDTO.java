package com.example.MonaServer.DTO;


import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Repository.TypeRepo;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Getter
@Setter
public class GroupDTO {

    Long groupId;

    private String name;

    private String groupAdmin;

    private String description;

    private byte[] profileImage;

    private Integer visibility;

    private Set<String> members;

    private Set<StickerTypeDTO> stickerTypes;

    private String inviteUrl;

    public GroupDTO(
            @JsonProperty("name") String name,
            @JsonProperty("groupAdmin") String groupAdmin,
            @JsonProperty("description") String description,
            @JsonProperty("profileImage") byte[] profileImage,
            @JsonProperty("visibility") int visibility) {
        this.name = name;
        this.groupAdmin = groupAdmin;
        this.description = description;
        this.profileImage = profileImage;
        this.visibility = visibility;
        this.members = null;
        this.stickerTypes = null;
        this.inviteUrl = null;
        this.groupId = null;
    }

    public GroupDTO(Group group, TypeRepo typeRepo) {
        this.name = group.getName();
        this.groupAdmin = group.getGroupAdmin().getUsername();
        this.description = group.getDescription();
        this.profileImage = group.getProfileImage();
        this.visibility = group.getVisibility();
        this.members = group.getMembers().stream().map(User::getUsername).collect(Collectors.toSet());
        this.stickerTypes = typeRepo.getTypesByGroup(group.getId()).stream().map(StickerTypeDTO::new).collect(Collectors.toSet());
        this.inviteUrl = group.getInviteUrl();
        this.groupId = group.getId();
    }

    public static List<GroupDTO> toDTOList(List<Group> groups, TypeRepo typeRepo) {
        return groups.stream().map(g -> new GroupDTO(g, typeRepo)).collect(Collectors.toList());
    }

    public static Set<GroupDTO> toDTOSet(Set<Group> groups, TypeRepo typeRepo) {
        return groups.stream().map(g -> new GroupDTO(g, typeRepo)).collect(Collectors.toSet());
    }
}
