package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashSet;
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
    UserRepo userRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value = "/api/groups")
    public Set<GroupDTO> getMonas (@RequestParam(required = false) Boolean pub) {
        if (pub != null && pub) {
            return GroupDTO.toDTOSet(
                    ((List<Group>) groupRepo.findAll()).
                        stream().
                        filter(m -> m.getVisibility() == 0).
                        collect(Collectors.toSet()));
        } else if (pub != null) {
            String username = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
            return GroupDTO.toDTOSet(
                    ((List<Group>) groupRepo.findAll()).
                            stream().
                            filter(m -> m.getMembers().contains(userRepo.findByUsername(username))).
                            collect(Collectors.toSet()));
        } else {
            return GroupDTO.toDTOSetPrivate(new HashSet<>(((List<Group>) groupRepo.findAll())));
        }

    }

    @RequestMapping(value = "/api/groups", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public GroupDTO createNewGroup(@RequestBody GroupDTO groupDTO) {
        String groupAdminUsername = groupDTO.getGroupAdmin();
        securityFilter.checkUserThrowsException(groupAdminUsername);
        Group group = groupRepo.createGroup(groupDTO);
        return new GroupDTO(group);
    }

    @RequestMapping(value = "/api/groups/{groupId}/members", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public GroupDTO addNewMember(@RequestBody GroupMemberJSON groupMemberJSON, @PathVariable Long groupId)  {
        securityFilter.checkUserThrowsException(groupMemberJSON.username());
        Group group = groupRepo.addGroupMember(groupId, groupMemberJSON.username(), groupMemberJSON.inviteUrl());
        return new GroupDTO(group);
    }

    @PutMapping("/api/groups/{groupId}")
    public GroupDTO updateGroup(@PathVariable Long groupId, @RequestBody GroupDTO groupDTO) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        groupDTO.setGroupId(groupId);
        group = groupRepo.updateGroup(groupDTO);
        return new GroupDTO(group);
    }


    @GetMapping("/api/groups/{groupId}/pins")
    public Set<PinDTO> getPinsOfGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserInGroupThrowsException(group);
        return PinDTO.toDTOSet(group.getPins());
    }

    @DeleteMapping("/api/groups/{groupId}/members")
    public void leaveGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        String username = securityFilter.checkUserInGroupThrowsException(group);
        groupRepo.deleteGroupMember(groupId, username);
    }

    @DeleteMapping("/api/groups/{groupId}")
    public void deleteGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        groupRepo.deleteGroup(groupId);
    }



}

record GroupMemberJSON(@JsonProperty("inviteUrl") String inviteUrl, @JsonProperty("username") String username) {}
