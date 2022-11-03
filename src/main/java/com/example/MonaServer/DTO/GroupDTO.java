package com.example.MonaServer.DTO;


import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Entities.User;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.*;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Getter
@Setter
public class GroupDTO {
    private String name;

    private UserDTO groupAdmin;

    private String description;

    private byte[] profileImage;

    private int visibility;

    private Set<UserDTO> members;

    private Set<StickerTypeDTO> stickerTypes;

    public GroupDTO(Group group) {
        this.name = group.getName();
        this.groupAdmin = new UserDTO(group.getGroupAdmin());
        this.description = group.getDescription();
        this.profileImage = group.getProfileImage();
        this.visibility = group.getVisibility();
        this.members = group.getMembers().stream().map(UserDTO::new).collect(Collectors.toSet());
        this.stickerTypes = group.getStickerTypes().stream().map(StickerTypeDTO::new).collect(Collectors.toSet());
    }

    public static List<GroupDTO> toDTOList(List<Group> groups) {
        return groups.stream().map(GroupDTO::new).collect(Collectors.toList());
    }

    public static Set<GroupDTO> toDTOSet(Set<Group> groups) {
        return groups.stream().map(GroupDTO::new).collect(Collectors.toSet());
    }
}
