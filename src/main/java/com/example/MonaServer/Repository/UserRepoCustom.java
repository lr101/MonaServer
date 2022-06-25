package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;

import java.util.List;

public interface UserRepoCustom {
    public Users findByUsername(String username);
    public Users updateUser(String username, int points);
    public List<Pin> addPinToFoundList(String username, Pin pin);
    public List<Pin> addPinToCreatedList(String username, Pin pin);
    public void deleteUser (String username);
    public List<Pin> getMappedPins(String username);
}
