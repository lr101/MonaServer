package com.example.MonaServer.Repository;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.UsernameXPoints;

import javax.transaction.Transactional;
import java.util.List;
import java.util.Set;
@Transactional
public interface GroupRepoCustom {
    public Group addGroupMember(Long groupId, String username, String inviteUrl);
    public Group deleteGroupMember(Long groupId, String username);
    public Group createGroup(GroupDTO groupDTO);
    public void deleteGroup(Long id);
    public Group getGroup(Long id);
    public Group updateGroup(GroupDTO groupDTO);
    public Set<Group> getGroupsOfUser(User user);

    public Set<Pin> getPinsOfUserInGroup(Long id, String username);
    public List<UsernameXPoints> getRankingOfGroup(Group group);
}
