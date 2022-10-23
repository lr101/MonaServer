package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;

import java.util.List;
import java.util.Set;

public interface UserRepoCustom {
    public User findByUsername(String username);
    public void deleteUser (String username);
    public void updateUser(String username, String password, String email, String token);
    public String setResetUrl(String username);
}
