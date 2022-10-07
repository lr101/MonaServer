package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.*;

public class UserRepoImpl implements UserRepoCustom {

    @Autowired
    @Lazy
    UserRepo userRepo;

    @Override
    public User findByUsername(String username) {
        Optional<User> user = userRepo.findById(username);
        return user.orElseThrow();
    }

    @Override
    public void deleteUser(String username) {
        userRepo.delete(findByUsername(username));
    }

    @Override
    public void updateUser(String username, String password, String email, String token) {
        User user = findByUsername(username);
        if (password != null) user.setPassword(password);
        if (email != null) user.setEmail(email);
        if (token != null) user.setToken(token);
        userRepo.save(user);
    }

}
