package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.UserPassword;
import com.example.MonaServer.Entities.Users;

import java.util.Set;

public interface UserPswRepoCustom {
    public UserPassword updateUserPassword(UserPassword userPassword);
    public UserPassword findUserById(String username);
    public void deleteUser (String username);
}
