package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Helper.UsernameXPoints;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.annotation.JsonProperty;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import javax.transaction.Transactional;
import java.util.*;
import java.util.stream.Collectors;

@RestController
@Transactional
public class RestControllerGroup {
    @Autowired
    GroupRepo groupRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    UserRepo userRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    //search value
    @GetMapping(value = "/api/groupIds")
    public List<Long> getGroupIds (@RequestParam String withUser, @RequestParam(required = false) String search) {
        String username = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (withUser.equals("true")) {
            return ((List<Group>) groupRepo.findAll())
                    .stream()
                    .filter(m -> search == null || m.getName().contains(search)) //search term filter
                    .filter(m -> m.getMembers().contains(userRepo.findByUsername(username)))
                    .sorted(Comparator.comparing(Group::getName))
                    .map(Group::getGroupId)
                    .collect(Collectors.toList());
        } else if (withUser.equals("false")) {
            return ((List<Group>) groupRepo.findAll())
                    .stream()
                    .filter(m -> search == null || m.getName().contains(search)) //search term filter
                    .filter(m -> !m.getMembers().contains(userRepo.findByUsername(username)))
                    .sorted(Comparator.comparing(Group::getName))
                    .map(Group::getGroupId)
                    .collect(Collectors.toList());

        }
        return new ArrayList<>();
    }

    /// Format: /api/groups?ids=0-1-2-3-4-5-6...
    @GetMapping(value = "/api/groups")
    public List<GroupDTO> getGroups(@RequestParam String ids) {
        List<Long> idList = Arrays.stream(ids.split("-")).map(Long::parseLong).collect(Collectors.toList());
        List<Group> groups = new ArrayList<>();
        idList.forEach(id -> groups.add(groupRepo.getGroup(id)));
        return GroupDTO.toDTOList(groups);
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

    @GetMapping( "/api/groups/{groupId}/members")
    public List<UsernameXPoints> getMembers(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        List<UsernameXPoints> list =  groupRepo.getRankingOfGroup(group);
        list.add(new UsernameXPoints(group.getGroupAdmin().getUsername(), -1));
        return list;
    }

    @GetMapping( "/api/groups/{groupId}/profile_image")
    public byte[] getProfileImage(@PathVariable Long groupId)  {
        return groupRepo.getGroup(groupId).getProfileImage();
    }

    @GetMapping( "/api/groups/{groupId}/pin_image")
    public byte[] getPinImage(@PathVariable Long groupId)  {
        return groupRepo.getGroup(groupId).getPinImage();
    }

    @GetMapping( "/api/groups/{groupId}/description")
    public String getDescription(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return groupRepo.getGroup(groupId).getDescription();
    }

    @GetMapping( "/api/groups/{groupId}/admin")
    public String getAdmin(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return groupRepo.getGroup(groupId).getGroupAdmin().getUsername();
    }

    @GetMapping( "/api/groups/{groupId}/invite_url")
    public String getInviteUrl(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return groupRepo.getGroup(groupId).getInviteUrl();
    }

    @GetMapping( "/api/groups/{groupId}")
    public GroupDTO getGroup(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        return new GroupDTO(group.getName(), group.getVisibility(), group.getGroupId());
    }

    @PutMapping("/api/groups/{groupId}")
    public GroupDTO updateGroup(@PathVariable Long groupId, @RequestBody GroupDTO groupDTO) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        groupDTO.setGroupId(groupId);
        group = groupRepo.updateGroup(groupDTO);
        return new GroupDTO(group);
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
