package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Entities.User;

import java.util.Date;

public interface GroupRepoCustom {
    public void updateGroup(byte[] image, Long id) ;
    public Group createGroup(byte[] image, double latitude, double longitude, User user, StickerType type, Date date);
    public void deleteGroup(Long id);
    public Group getGroup(Long id);
}
