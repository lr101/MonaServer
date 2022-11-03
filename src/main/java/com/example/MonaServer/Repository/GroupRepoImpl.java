package com.example.MonaServer.Repository;

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


    @Override
    public Group createGroup(byte[] image, double latitude, double longitude, User user, StickerType type, Date date) {
        //TODO
        return null;
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
    public void updateGroup(byte[] image, Long id) {
        Group group = getGroup(id);
        //TODO
        groupRepo.save(group);
    }

}
