package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;

import java.util.List;
import java.util.Set;

public interface UserRepoCustom {
    public Users findByUsername(String username);
    public Users updateUser(String username, int points);
    public Set<Pin> addPinToFoundList(String username, Pin pin);
    public Set<Pin> addPinToCreatedList(String username, Pin pin);
    public void deleteUser (String username);
    public Set<Pin> getMappedPins(String username);
}
