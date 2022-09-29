package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;

import java.util.List;
import java.util.Set;

public interface UserRepoCustom {
    public Users findByUsername(String username);
    public void addPinToCreatedList(String username, Pin pin);
    public void deleteUser (String username);
    public Set<Pin> getMappedPins(String username);
    public List<Object[]> getRanking();
    public Users findUserByPin(Pin pin);
}
