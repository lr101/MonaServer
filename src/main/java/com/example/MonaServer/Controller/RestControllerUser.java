package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.UserPassword;
import com.example.MonaServer.Entities.Users;
import com.example.MonaServer.Helper.UsernameXPoints;
import com.example.MonaServer.Repository.UserPswRepo;
import com.example.MonaServer.Repository.UserRepo;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@RestController
public class RestControllerUser {

    @Autowired
    UserRepo userRepo;

    @Autowired
    UserPswRepo userPswRepo;


    @GetMapping(value ="/users/")
    public ArrayList<Users> getAllUsers() {
        return (ArrayList<Users>) userRepo.findAll();
    }


    @GetMapping(value = "/users/{user}/")
    public Users getUser (@PathVariable("user") String username) {
        return userRepo.findByUsername(username);
    }

    @GetMapping(value = "/users/{user}/points")
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

    @GetMapping(value = "/users/ranking")
    public List<UsernameXPoints> getPointRanking () {
        return calcPoints();
    }

    private List<UsernameXPoints> calcPoints () {
        List<Users> users = (List<Users>) userRepo.findAll();
        for (Users user : users) {
            int points = 0;
            for (Pin pin : user.getCreatedPins()) {
                if(pin.getType().getId() == 0) {
                    points+=1;
                } else if (pin.getType().getId() == 1) {
                    points+=1;
                }
            }
            userRepo.updateUser(user.getUsername(), points);
        }
        return userRepo.getRanking();
    }

    @GetMapping(value = "/users/{user}/check")
    public String checkUser(@PathVariable("user") String username) {
        Optional<UserPassword> up = userPswRepo.findById(username);
        Optional<Users> up2 = userRepo.findById(username);
        if (up.isPresent() && up2.isPresent()) {
            return up.get().getPassword();
        }
        throw new IllegalArgumentException("user does not exist");
    }

    //working
    @PostMapping("/users/")
    public Users postUser(@RequestBody ObjectNode json) throws Exception {
        String username = json.get("username").asText();
        String password = json.get("password").asText();
        String email = json.get("email").asText();
        try {
            checkUser(username);
        } catch (Exception e) {
            userPswRepo.save(new UserPassword(username, password, email));
            return userRepo.save(new Users(username));
        }
        throw new Exception("user already exists");
    }

    @PutMapping("/users/password/")
    public boolean putUserPassword(@RequestBody ObjectNode json) throws Exception {
        String username = json.get("username").asText();
        String password = json.get("password").asText();
        try {
            checkUser(username);
            return userPswRepo.updatePassword(username,password);
        } catch (Exception e) {

        }
        throw new Exception("user does not exist");
    }

    @PutMapping("/users/email/")
    public boolean putUserEmail(@RequestBody ObjectNode json) throws Exception {
        String username = json.get("username").asText();
        String email = json.get("email").asText();
        try {
            checkUser(username);
            return userPswRepo.updateEmail(username,email);
        } catch (Exception e) {

        }
        throw new Exception("user does not exist");
    }

    @DeleteMapping("/users/{user}")
    public void deleteUser (@PathVariable("user") String username) {
        userRepo.deleteUser(username);
    }
}
