package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;

import java.util.Set;

public interface UserPswRepoCustom {
    public boolean updatePassword(String username, String password);
    public boolean updateEmail(String username, String email);
}
