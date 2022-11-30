package com.example.MonaServer.Repository;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.*;
import com.example.MonaServer.Helper.UsernameXPoints;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.*;

public class GroupRepoImpl implements GroupRepoCustom {

    @Autowired
    @Lazy
    GroupRepo groupRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    UserRepo userRepo;


    @Override
    public Group addGroupMember(Long groupId, String username, String inviteUrl) {
        Group group = getGroup(groupId);
        if (group.getVisibility() == 0 || (group.getVisibility() !=0 && group.getInviteUrl().equals(inviteUrl))) {
            group.addGroupMember(userRepo.findByUsername(username));
            return groupRepo.save(group);
        }
        throw new SecurityException("ERROR: joining group not possible with the current credentials");
    }

    @Override
    public Group deleteGroupMember(Long groupId, String username) {
        Group group = getGroup(groupId);
        if (!username.equals(group.getGroupAdmin().getUsername())) {
            group.removeGroupMember(username);
            return groupRepo.save(group);
        }
        throw new IllegalArgumentException("ERROR: you are leaving the group as an admin. Try making another group member the admin first");
    }

    @Override
    public Group createGroup(GroupDTO groupDTO) {
        if (groupDTO.getVisibility() != null &&
            groupDTO.getProfileImage() != null &&
            groupDTO.getName() != null) {
            Group group = new Group(groupDTO, userRepo.findByUsername(groupDTO.getGroupAdmin()));
            return groupRepo.save(group);
        }
        throw new IllegalArgumentException("The group has missing necessary params");
    }

    @Override
    public void deleteGroup(Long id){
        Group group = getGroup(id);
        groupRepo.delete(group);
    }

    @Override
    public Group getGroup(Long id) {
        Optional<Group> group = groupRepo.findById(id);
        return group.orElseThrow();
    }

    @Override
    public Group updateGroup(GroupDTO groupDTO) {
        Group group = getGroup(groupDTO.getGroupId());
        if (groupDTO.getDescription() != null)  group.setDescription(groupDTO.getDescription());
        if (groupDTO.getGroupAdmin() != null)   group.setGroupAdmin(userRepo.findByUsername(groupDTO.getGroupAdmin()));
        if (groupDTO.getName() != null)         group.setName(groupDTO.getName());
        if (groupDTO.getProfileImage() != null) group.updateGroupImage(groupDTO.getProfileImage());
        if (groupDTO.getVisibility() != null)   {
            group.setVisibility(groupDTO.getVisibility());
            group.setInvite();
        }
        return groupRepo.save(group);
    }

    @Override
    public Set<Group> getGroupsOfUser(User user) {
        List<Group> groups = (List<Group>) groupRepo.findAll();
        Set<Group> userGroups = new HashSet<>();
        for (Group group : groups) {
            if (group.getMembers().contains(user)) {
                userGroups.add(group);
            }
        }
        return userGroups;
    }

    @Override
    public List<UsernameXPoints> getRankingOfGroup(Group group) {
        List<UsernameXPoints> list = new ArrayList<>();
        Map<User, UsernameXPoints> ranking = new HashMap<>();
        group.getMembers().forEach(u -> {
            UsernameXPoints i = new UsernameXPoints(u.getUsername(), 0);
            list.add(i);
            ranking.put(u, i);
        });

        for (Pin pin : group.getPins()) {
            UsernameXPoints points = ranking.get(pin.getUser());
            if (points != null) points.addOnePoint();
        }
        list.sort(Comparator.comparing(UsernameXPoints::getPoints).reversed());
        return list;
    }

}
