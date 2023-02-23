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

    /**
     * Request to get all group ids fulfilling specification of request params.
     * @param withUser flag for returning
     *                 (true) only groups containing requesting user
     *                 (false) only groups not containing requesting user
     * @param search search term for filtering group name. Returns all groups on null or not existing.
     * @return list of group ids
     */
    @GetMapping(value = "/api/groupIds")
    public List<Long> getGroupIds (@RequestParam String withUser, @RequestParam(required = false) String search) {
        String username = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (withUser.equals("true")) {
            return ((List<Group>) groupRepo.findAll())
                    .stream()
                    .filter(m -> search == null || m.getName().toLowerCase().contains(search.toLowerCase())) //search term filter
                    .filter(m -> m.getMembers().contains(userRepo.findByUsername(username)))
                    .sorted(Comparator.comparing(Group::getName))
                    .map(Group::getGroupId)
                    .collect(Collectors.toList());
        } else if (withUser.equals("false")) {
            return ((List<Group>) groupRepo.findAll())
                    .stream()
                    .filter(m -> search == null || m.getName().toLowerCase().contains(search.toLowerCase())) //search term filter
                    .filter(m -> !m.getMembers().contains(userRepo.findByUsername(username)))
                    .sorted(Comparator.comparing(Group::getName))
                    .map(Group::getGroupId)
                    .collect(Collectors.toList());

        }
        return new ArrayList<>();
    }

    /// Format: /api/groups?ids=0-1-2-3-4-5-6...

    /**
     * Request to get all publicly available information on groups from [ids] string.
     * @param ids is a string containing the requested group ids. Format: /api/groups?ids=0-1-2-3-4-5-6-...
     * @return List of groups containing group name, visibility, group id
     */
    @GetMapping(value = "/api/groups")
    public List<GroupDTO> getGroups(@RequestParam String ids) {
        List<Long> idList = Arrays.stream(ids.split("-")).map(Long::parseLong).toList();
        List<Group> groups = new ArrayList<>();
        idList.forEach(id -> groups.add(groupRepo.getGroup(id)));
        return GroupDTO.toDTOList(groups);
    }

    /**
     * Request to create a new group. Group admin must be the requesting user.
     * @param groupDTO group containing name, groupAdmin, description, profileImage, visibility
     * @return group containing name, groupAdmin, description, profileImage, visibility, inviteUrl, groupId, pinImage
     */
    @RequestMapping(value = "/api/groups", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public GroupDTO createNewGroup(@RequestBody GroupDTO groupDTO) {
        String groupAdminUsername = groupDTO.getGroupAdmin();
        securityFilter.checkUserThrowsException(groupAdminUsername);
        Group group = groupRepo.createGroup(groupDTO);
        return new GroupDTO(group);
    }

    /**
     * Request to join a group.
     * Needs a valid inviteUrl when group is private
     * @param groupMemberJSON Body containing groupId, username, inviteUrl
     * @param groupId identifies the group to join
     * @return group containing name, groupAdmin, description, profileImage, visibility, inviteUrl, groupId, pinImage
     */
    @RequestMapping(value = "/api/groups/{groupId}/members", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public GroupDTO addNewMember(@RequestBody GroupMemberJSON groupMemberJSON, @PathVariable Long groupId)  {
        securityFilter.checkUserThrowsException(groupMemberJSON.username());
        Group group = groupRepo.addGroupMember(groupId, groupMemberJSON.username(), groupMemberJSON.inviteUrl());
        return new GroupDTO(group);
    }

    /**
     * Request to get member list.
     * Requesting user must be a member of the group or the group must be public.
     * @param groupId identifies the group
     * @return List of usernames of group members and their corresponding points.
     * The last member (with points of -1) is the group admin.
     */
    @GetMapping( "/api/groups/{groupId}/members")
    public List<UsernameXPoints> getMembers(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        List<UsernameXPoints> list =  groupRepo.getRankingOfGroup(group);
        list.add(new UsernameXPoints(group.getGroupAdmin().getUsername(), -1));
        return list;
    }

    /**
     * Request to get the full sized profile image of a group.
     * @param groupId identifies group
     * @return image data as byte array
     */
    @GetMapping( "/api/groups/{groupId}/profile_image")
    public byte[] getProfileImage(@PathVariable Long groupId)  {
        return groupRepo.getGroup(groupId).getProfileImage();
    }

    /**
     * Request to get reduced sized profile image of a group
     * @param groupId identifies group
     * @return image data as byte array
     */
    @GetMapping( "/api/groups/{groupId}/pin_image")
    public byte[] getPinImage(@PathVariable Long groupId)  {
        return groupRepo.getGroup(groupId).getPinImage();
    }

    /**
     * Request to get description of a group.
     * Requesting user must be a member of the group or the group must be public.
     * @param groupId identifies group
     * @return description as a string
     */
    @GetMapping( "/api/groups/{groupId}/description")
    public String getDescription(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return groupRepo.getGroup(groupId).getDescription();
    }

    /**
     * Request to get the admin username of a group
     * Requesting user must be a member of the group or the group must be public.
     * @param groupId identifies a group
     * @return username of admin
     */
    @GetMapping( "/api/groups/{groupId}/admin")
    public String getAdmin(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return groupRepo.getGroup(groupId).getGroupAdmin().getUsername();
    }

    /**
     * Request to get the invite url of a private group
     * Requesting user must be a member of the group
     * TODO will invite url be set null on public? sonst: throw error when asking for public group
     * @param groupId identifies group
     * @return invite url as string
     */
    @GetMapping( "/api/groups/{groupId}/invite_url")
    public String getInviteUrl(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return groupRepo.getGroup(groupId).getInviteUrl();
    }

    /**
     * Request to get public information of a specific group
     * @param groupId identifies group
     * @return Group containing name, visibility, group id
     */
    @GetMapping( "/api/groups/{groupId}")
    public GroupDTO getGroup(@PathVariable Long groupId)  {
        Group group = groupRepo.getGroup(groupId);
        return new GroupDTO(group.getName(), group.getVisibility(), group.getGroupId());
    }

    /**
     * Request to update a group.
     * Requesting user must be an admin of the group.
     * @param groupId identifies group
     * @param groupDTO group containing updated information. All attributes that are not null will be updated.
     * @return group containing all information
     */
    @PutMapping("/api/groups/{groupId}")
    public GroupDTO updateGroup(@PathVariable Long groupId, @RequestBody GroupDTO groupDTO) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        groupDTO.setGroupId(groupId);
        group = groupRepo.updateGroup(groupDTO);
        return new GroupDTO(group);
    }

    /**
     * Request to leave a group.
     * Requesting user must be a member of the group.
     * TODO delete group if member is last member
     * TODO dont leave group if member is group admin
     * @param groupId identifies group
     */
    @DeleteMapping("/api/groups/{groupId}/members")
    public void leaveGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        String username = securityFilter.checkUserInGroupThrowsException(group);
        groupRepo.deleteGroupMember(groupId, username);
    }

    /**
     * Request to delete a group. Group must only contain user as the last member.
     * Requesting user must be the admin of the group.
     * @param groupId identifies group
     */
    @DeleteMapping("/api/groups/{groupId}")
    public void deleteGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserAdminInGroupThrowsException(group);
        if (group.getMembers().size() == 0) {
            groupRepo.deleteGroup(groupId);
        } else {
            throw new SecurityException("Denied: group can only be delete with one user as a member");
        }
    }



}

record GroupMemberJSON(@JsonProperty("inviteUrl") String inviteUrl, @JsonProperty("username") String username) {}
