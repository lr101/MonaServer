package com.example.MonaServer.DTO;


import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.UsernameXPoints;
import com.example.MonaServer.Repository.GroupRepo;
import com.example.MonaServer.Repository.GroupRepoImpl;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;
import org.jetbrains.annotations.NotNull;
import org.springframework.beans.factory.annotation.Autowired;

import javax.persistence.ColumnResult;
import javax.persistence.ConstructorResult;
import javax.persistence.Entity;
import javax.persistence.SqlResultSetMapping;
import java.util.*;
import java.util.stream.Collectors;

@Getter
@Setter
@SqlResultSetMapping(
        name = "map_complete_group",
        classes = @ConstructorResult(
                targetClass = Group.class,
                columns = {
                        @ColumnResult(name = "groupId", type = Long.class),
                        @ColumnResult(name = "name", type = String.class),
                        @ColumnResult(name = "groupAdmin", type = Integer.class),
                        @ColumnResult(name = "visibility", type = Integer.class),
                        @ColumnResult(name = "inviteUrl", type = Integer.class),
                }
        )
)
public class GroupDTO {

    Long groupId;

    private String name;

    private String groupAdmin;

    private String description;

    private byte[] profileImage;

    private byte[] pinImage;

    private Integer visibility;

    private String inviteUrl;

    private List<Map<String, Object>> members;

    public GroupDTO(
            @JsonProperty("name") String name,
            @JsonProperty("groupAdmin") String groupAdmin,
            @JsonProperty("description") String description,
            @JsonProperty("profileImage") byte[] profileImage,
            @JsonProperty("visibility") Integer visibility) {
        this.name = name;
        this.groupAdmin = groupAdmin;
        this.description = description;
        this.profileImage = profileImage;
        this.visibility = visibility;
    }

    public GroupDTO(
             String name,
             Integer visibility,
             Long groupId) {
        this.name = name;
        this.visibility = visibility;
        this.groupId = groupId;
    }

    public GroupDTO(Group group, GroupRepo groupRepo) {
        this.name = group.getName();
        this.groupAdmin = group.getGroupAdmin().getUsername();
        this.description = group.getDescription();
        this.profileImage = group.getProfileImage();
        this.visibility = group.getVisibility();
        this.inviteUrl = group.getInviteUrl();
        this.groupId = group.getGroupId();
        this.pinImage = group.getPinImage();
        this.members = getRankingOfGroup(group, groupRepo);
    }

    public static List<GroupDTO> toDTOList(List<Group> groups) {
        return groups.stream().map(GroupDTO::getPrivateDTO).collect(Collectors.toList());
    }

    public static Set<GroupDTO> toDTOSet(Set<Group> groups, GroupRepo groupRepo) {
        return groups.stream().map(e -> new GroupDTO(e, groupRepo)).collect(Collectors.toSet());
    }

    public static Set<GroupDTO> toDTOSetPrivate(Set<Group> groups) {
        return groups.stream().map(GroupDTO::getPrivateDTO).collect(Collectors.toSet());
    }

    public static GroupDTO getPrivateDTO(Group group) {
        return new GroupDTO(group.getName(),  group.getVisibility(), group.getGroupId());
    }

    private List<Map<String, Object>> getRankingOfGroup(Group group, GroupRepo groupRepo) {
        return groupRepo.getRankingByQuery(group.getGroupId());
    }


}
