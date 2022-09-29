package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.UserPassword;
import com.example.MonaServer.Entities.Users;
import com.example.MonaServer.Helper.UsernameXPoints;
import com.example.MonaServer.Repository.PinRepo;
import com.example.MonaServer.Repository.UserPswRepo;
import com.example.MonaServer.Repository.UserRepo;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

@RestController
public class RestControllerUser {

    @Autowired
    UserRepo userRepo;

    @Autowired
    UserPswRepo userPswRepo;

    @Autowired
    PinRepo pinRepo;

    @GetMapping(value ="/users/")
    public ArrayList<Users> getAllUsers() {
        return (ArrayList<Users>) userRepo.findAll();
    }

    @PostMapping("/users/")
    public Users postUser(@RequestBody ObjectNode json) throws Exception {
        String username = json.get("username").asText();
        String password = json.get("password").asText();
        String email = json.get("email").asText();
        if (!checkForUser(username)) {
            userPswRepo.save(new UserPassword(username, password, email));
            return userRepo.save(new Users(username));
        }
        throw new Exception("user already exists");
    }

    @GetMapping(value = "/users/{user}")
    public Users getUser (@PathVariable("user") String username) {
        return userRepo.findByUsername(username);
    }

    @PutMapping("/users/{user}")
    public boolean putUser(@PathVariable("user") String username, @RequestBody ObjectNode json) throws Exception {
        String email = json.get("email").asText();
        String password = json.get("password").asText();
        if (checkForUser(username)) {
            userPswRepo.updateUserPassword(new UserPassword(username, password, email));
            return true;
        }
        throw new Exception("user does not exist");
    }

    @DeleteMapping("/users/{user}")
    public void deleteUser (@PathVariable("user") String username) {
        userRepo.deleteUser(username);
        userPswRepo.deleteUser(username);
    }

    @GetMapping(value = "/users/{user}/points/")
    public int getUserPoints (@PathVariable("user") String username) {
        int points = 0;
        for (Pin pin : userRepo.findByUsername(username).getCreatedPins()) {
            if(pin.getType().getId() == 0) {
                points+=1;
            } else if (pin.getType().getId() == 1) {
                points+=1;
            }
        }
        return points;
    }

    @GetMapping(value = "/users/{user}/password")
    public String getPassword(@PathVariable("user") String username) {
        Optional<UserPassword> up = userPswRepo.findById(username);
        Optional<Users> up2 = userRepo.findById(username);
        if (up.isPresent() && up2.isPresent()) {
            return up.get().getPassword();
        }
        throw new IllegalArgumentException("user does not exist");
    }

    @GetMapping(value = "/users/{user}/created-pins")
    public Set<Pin> getPinsOfUser (@PathVariable("user") String username) {
        return userRepo.getMappedPins(username);
    }

    @GetMapping(value = "/users/{user}/not-created-pins")
    public Set<Pin> getPinsNotOfUser (@PathVariable("user") String username) {
        Set<Pin> userPins = userRepo.getMappedPins(username);
        return ((List<Pin>) pinRepo.findAll()).stream().filter(p -> !userPins.contains(p)).collect(Collectors.toSet());
    }

    public boolean checkForUser(String username) {
        Optional<UserPassword> up = userPswRepo.findById(username);
        Optional<Users> up2 = userRepo.findById(username);
        return up.isPresent() || up2.isPresent();
    }



}
