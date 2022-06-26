package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Users;
import com.example.MonaServer.Repository.UserRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;

@RestController
public class RestControllerUser {

    @Autowired
    UserRepo userRepo;

    @GetMapping(value ="/users/")
    public ArrayList<Users> getAllUsers() {
        return (ArrayList<Users>) userRepo.findAll();
    }

    //working
    @GetMapping(value = "/users/{user}/")
    public Users getUser (@PathVariable("user") String username) {
        return userRepo.findByUsername(username);
    }

    @GetMapping(value = "/users/{user}/check")
    public boolean checkUser(@PathVariable("user") String username) {
        return userRepo.findByUsername(username) != null;
    }

    //working
    @PostMapping("/users/")
    public Users postSensor(@RequestBody Users user) throws Exception {
        if (checkUser(user.getUsername())) {
            throw new Exception("user already exists");
        }
        return userRepo.save(user);
    }

    @DeleteMapping("/monas/{user}")
    public void deleteMona (@PathVariable("user") String username) {
        userRepo.deleteUser(username);
    }
}
