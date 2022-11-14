package com.example.MonaServer.DTO;


import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.User;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
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

    private byte[] pinImage;

    private Integer visibility;

    private Set<String> members;

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
    }

    public GroupDTO(
             String name,
             byte[] profileImage,
             int visibility,
             Long groupId) {
        this.name = name;
        this.profileImage = profileImage;
        this.visibility = visibility;
        this.groupId = groupId;
    }

    public GroupDTO(Group group) {
        this.name = group.getName();
        this.groupAdmin = group.getGroupAdmin().getUsername();
        this.description = group.getDescription();
        this.profileImage = group.getProfileImage();
        this.visibility = group.getVisibility();
        this.members = group.getMembers().stream().map(User::getUsername).collect(Collectors.toSet());
        this.inviteUrl = group.getInviteUrl();
        this.groupId = group.getGroupId();
        this.pinImage = group.getPinImage();
    }

    public static List<GroupDTO> toDTOList(List<Group> groups) {
        return groups.stream().map(GroupDTO::new).collect(Collectors.toList());
    }

    public static Set<GroupDTO> toDTOSet(Set<Group> groups) {
        return groups.stream().map(GroupDTO::new).collect(Collectors.toSet());
    }

    public static Set<GroupDTO> toDTOSetPrivate(Set<Group> groups) {
        return groups.stream().map(GroupDTO::getPrivateDTO).collect(Collectors.toSet());
    }

    private static GroupDTO getPrivateDTO(Group group) {
        if (group.getVisibility() == 0) {
            return new GroupDTO(group);
        } else {
            return new GroupDTO(group.getName(), group.getProfileImage(), group.getVisibility(), group.getGroupId());
        }
    }
}
