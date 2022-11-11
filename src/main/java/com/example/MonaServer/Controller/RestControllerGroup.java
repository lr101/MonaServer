package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.DTO.StickerTypeDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
public class RestControllerGroup {
    @Autowired
    GroupRepo groupRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    TypeRepo typeRepo;

    @Autowired
    UserRepo userRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value = "/api/groups")
    public Set<GroupDTO> getMonas (@RequestParam(required = false) Boolean publicGroups) {
        if (publicGroups != null && publicGroups) {
            return GroupDTO.toDTOSet((Set<Group>) groupRepo.findAll(), typeRepo).
                    stream().
                    filter(m -> m.getVisibility() == 0).
                    collect(Collectors.toSet());
        } else {
            String username = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
            return GroupDTO.toDTOSet(

                    ((List<Group>) groupRepo.findAll()).
                            stream().
                            filter(m -> m.getMembers().contains(userRepo.findByUsername(username))).
                            collect(Collectors.toSet())

                    , typeRepo);
        }

    }

    @RequestMapping(value = "/api/groups", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public GroupDTO createNewGroup(@RequestBody GroupDTO groupDTO) {
        String groupAdminUsername = groupDTO.getGroupAdmin();
        securityFilter.checkUserThrowsException(groupAdminUsername);
        Group group = groupRepo.createGroup(groupDTO);
        return new GroupDTO(group, typeRepo);
    }

    @RequestMapping(value = "/api/groups/{groupId}/members", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public GroupDTO addNewMember(@RequestBody GroupMemberJSON groupMemberJSON, @PathVariable Long groupId)  {
        securityFilter.checkUserThrowsException(groupMemberJSON.username());
        Group group = groupRepo.addGroupMember(groupId, groupMemberJSON.username(), groupMemberJSON.inviteUrl());
        return new GroupDTO(group, typeRepo);
    }

    @PutMapping("/api/groups/{groupId}")
    public GroupDTO updateGroup(@PathVariable Long groupId, @RequestBody GroupDTO groupDTO) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        groupDTO.setGroupId(groupId);
        group = groupRepo.updateGroup(groupDTO);
        return new GroupDTO(group, typeRepo);
    }

    @PutMapping("/api/groups/{groupId}/types")
    public StickerTypeDTO updateGroupTypes(@PathVariable Long groupId, @RequestBody GroupTypeJSON type) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        return new StickerTypeDTO(groupRepo.addTypeToGroup(groupId, type.name(), type.icon()));
    }

    @DeleteMapping("/api/groups/{groupId}")
    public void deleteGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        groupRepo.deleteGroup(groupId);
    }



}

record GroupMemberJSON(@JsonProperty("inviteUrl") String inviteUrl, @JsonProperty("username") String username) {}
record GroupTypeJSON(@JsonProperty("name") String name, @JsonProperty("icon") byte[] icon, @JsonProperty("group") Long groupId) {}
