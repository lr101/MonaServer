package com.example.MonaServer.Repository;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.Date;
import java.util.NoSuchElementException;
import java.util.Optional;

public class GroupRepoImpl implements GroupRepoCustom {

    @Autowired
    @Lazy
    GroupRepo groupRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    UserRepo userRepo;

    @Autowired
    TypeRepo typeRepo;


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
    public Group createGroup(GroupDTO groupDTO) {
        Group group = new Group(groupDTO, userRepo.findByUsername(groupDTO.getGroupAdmin()));
        return groupRepo.save(group);
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
        if (groupDTO.getProfileImage() != null) group.setProfileImage(groupDTO.getProfileImage());
        if (groupDTO.getVisibility() != null)   {
            group.setVisibility(groupDTO.getVisibility());
            group.setInvite();
        }
        return groupRepo.save(group);
    }

    @Override
    public StickerType addTypeToGroup(Long groupId, String name, byte[] icon) {
        Group group = getGroup(groupId);
        StickerType type = new StickerType(name, icon, group);
        return typeRepo.save(type);
    }

}
