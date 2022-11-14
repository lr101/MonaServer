package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;

import java.util.Date;

public interface MonaRepoCustom {
    public void updateMona(byte[] image, Long id) ;
    public Pin createMona(byte[] image, double latitude, double longitude, User user, Date date);
    public void deleteMona(Long id);
    public Mona getMona(Long pinId);
}
