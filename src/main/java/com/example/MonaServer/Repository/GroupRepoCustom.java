package com.example.MonaServer.Repository;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.User;

import java.util.Set;

public interface GroupRepoCustom {
    public Group addGroupMember(Long groupId, String username, String inviteUrl);
    public Group deleteGroupMember(Long groupId, String username);
    public Group createGroup(GroupDTO groupDTO);
    public void deleteGroup(Long id);
    public Group getGroup(Long id);
    public Group updateGroup(GroupDTO groupDTO);
    public Set<Group> getGroupsOfUser(User user);
}
