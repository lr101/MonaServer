package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.UserPassword;
import com.example.MonaServer.Entities.Users;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.*;

public class UserPswRepoImpl implements UserPswRepoCustom {

    @Autowired
    @Lazy
    UserPswRepo userPswRepo;

    @Override
    public boolean updatePassword(String username, String password) {
        Optional<UserPassword> up = userPswRepo.findById(username);
        if (up.isPresent()){
            UserPassword userPassword = up.get();
            userPassword.setPassword(password);
            userPswRepo.save(userPassword);
            return true;
        }
        return false;
    }

    @Override
    public boolean updateEmail(String username, String email) {
        Optional<UserPassword> up = userPswRepo.findById(username);
        if (up.isPresent()){
            UserPassword userPassword = up.get();
            userPassword.setEmail(email);
            userPswRepo.save(userPassword);
            return true;
        }
        return false;
    }
}
