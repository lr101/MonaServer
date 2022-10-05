package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
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
    public UserPassword findUserById(String username) {
        Optional<UserPassword> m = userPswRepo.findById(username);
        return m.orElse(null);
    }

    @Override
    public UserPassword updateUserPassword(UserPassword userPassword) {
        UserPassword up = findUserById(userPassword.getUsername());
        if (userPassword.getPassword() != null) {
            up.setPassword(userPassword.getPassword());
        }
        if (userPassword.getEmail() != null) {
            up.setEmail(userPassword.getEmail());
        }
        userPswRepo.save(up);
        return up;
    }

    @Override
    public void deleteUser(String username) {
        userPswRepo.delete(findUserById(username));
    }

    @Override
    public Optional<UserPassword> findByToken(String token) {
        for (UserPassword up : userPswRepo.findAll()) {
            if (up.getToken().equals(token)) {
                return Optional.of(up);
            }
        }
        return Optional.empty();
    }
}
