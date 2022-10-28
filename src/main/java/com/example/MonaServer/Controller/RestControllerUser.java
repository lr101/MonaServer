package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.UserDTO;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.EmailHelper;
import com.example.MonaServer.Helper.JWTUtil;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.UserRepo;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
public class RestControllerUser {

    @Autowired
    UserRepo userRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value ="/api/users")
    public List<UserDTO> getAllUsers() {
        return UserDTO.toDTOList((List<User>) userRepo.findAll());
    }

    @GetMapping(value = "/api/users/{user}")
    public UserDTO getUser (@PathVariable("user") String username) {
        return new UserDTO(userRepo.findByUsername(username));
    }

    @PutMapping("/api/users/{user}")
    public void putUser(@PathVariable("user") String username, @RequestBody ObjectNode json) {
        securityFilter.checkUserThrowsException(username);
        String email = null;
        String password = null;
        if(json.has("email")) email = json.get("email").asText();
        if(json.has("password")) password = json.get("password").asText();
        userRepo.updateUser(username, password, email, null);
    }

    @DeleteMapping("/api/users/{user}")
    public void deleteUser (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        userRepo.deleteUser(username);
    }

    @GetMapping(value = "/api/users/{user}/points")
    public Long getUserPoints (@PathVariable("user") String username) {
        if (checkForUser(username)) throw  new NoSuchElementException("ERROR: User with username: " + username + " does not exist");
        return userRepo.getUserPoints(username);
    }

    public boolean checkForUser(String username) {
        Optional<User> user = userRepo.findById(username);
        return user.isEmpty();
    }

    //#################### Authentication routes ##########################

    @PostMapping("/signup")
    public String postUser(@RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"email", "password", "username"});
        String email = json.get("email").asText();
        String password = json.get("password").asText();
        String username = json.get("username").asText();
        if (checkForUser(username)) {
            User user = userRepo.save(new User(username, password, email, new JWTUtil().generateToken(username)));
            return user.getToken();
        }
        throw new IllegalArgumentException("User with username: " + username + " already exists");
    }

    @GetMapping(value = "/login/{user}")
    public String loginOld(@PathVariable("user") String username) {
        User user = userRepo.findByUsername(username);
        if (user.getToken() == null) {
            return user.getPassword();
        }
        throw new IllegalArgumentException ("Wrong login format, because token already exists. Try using POST [IP]:[PORT]/login/");
    }

    @PostMapping(value = "/login")
    public String login(@RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"password", "username"});
        String password = json.get("password").asText();
        String username = json.get("username").asText();
        User user = userRepo.findByUsername(username);
        if(user.getPassword().equals(password)) {
            String token = user.getToken();
            if (token == null) {
                token = new JWTUtil().generateToken(username);
                userRepo.updateUser(username, null, null, token);
            }
            return token;
        }
        throw new IllegalArgumentException("ERROR: Wrong Password");
    }

    @GetMapping(value = "/recover")
    public void recover(@RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"username"});
        String username = json.get("username").asText();
        User user = userRepo.findByUsername(username);

        if (user.getEmail() != null) {
            String url = userRepo.setResetUrl(username);
            new EmailHelper().sendMail("You applied for recovering your password. You can do so by pressing the link below:\n\nhttps://localhost:8081/public/recover/" + url + "\n\nThis link will be active for 24h\n Thank you for using this STICKER MAP", user.getEmail());
        }
    }

    //TODO Delete if all users switched to new type of encoding
    @PutMapping("/token/{user}")
    public String putUserToken(@PathVariable("user") String username, @RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"password"});
        String password = json.get("password").asText();
        String token = new JWTUtil().generateToken(username);
        userRepo.updateUser(username, password, null, token);
        return token;
    }



}
