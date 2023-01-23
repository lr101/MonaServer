package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.DTO.MonaDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.DTO.UserDTO;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.EmailHelper;
import com.example.MonaServer.Helper.JWTUtil;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.GroupRepo;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.UserRepo;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

import javax.transaction.Transactional;
import java.io.IOException;
import java.net.InetAddress;
import java.net.UnknownHostException;
import java.util.*;

@RestController
@Transactional
public class RestControllerUser {

    @Autowired
    UserRepo userRepo;

    @Autowired
    GroupRepo groupRepo;

    @Autowired
    MonaRepo monaRepo;

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

    @GetMapping(value = "/api/users/{user}/email")
    public String getUserEmail (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        return userRepo.findByUsername(username).getEmail();
    }

    @GetMapping(value = "/api/users/{user}/groups")
    public Set<GroupDTO> getUserGroups (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        return GroupDTO.toDTOSetPrivate(groupRepo.getGroupsOfUser(userRepo.findByUsername(username)));
    }

    @GetMapping(value = "/api/users/{user}/pins")
    public List<Long> getUserPins (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        User user = userRepo.findByUsername(username);
        return MonaDTO
                .toDTOList(monaRepo.getMonasByUser(user))
                .stream()
                .sorted(Comparator.comparing(a -> a.getPin().getCreationDate(), Comparator.reverseOrder()))
                .map(e -> e.getPin().getId())
                .toList();
    }

    @GetMapping(value = "/api/users/{user}/pins/{groupId}")
    public Set<PinDTO> getUserPinsByGroup (@PathVariable("user") String username, @PathVariable("groupId") Long groupId) {
        securityFilter.checkUserInGroupThrowsException(groupRepo.getGroup(groupId));
        return PinDTO.toDTOSet(groupRepo.getPinsOfUserInGroup(groupId, username));
    }

    @PutMapping(value = "/api/users/{user}/profile_picture")
    public byte[] putUserProfilePicture (@PathVariable("user") String username, @RequestBody ObjectNode json) throws IOException {
        securityFilter.checkJsonForValues(json, new String[] {"image"});
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        return userRepo.updateProfilePicture(username, reader.readValue(json.get("image")));
    }

    @GetMapping(value = "/api/users/{user}/profile_picture")
    public byte[] getUserProfilePicture (@PathVariable("user") String username) {
        return userRepo.findByUsername(username).getProfilePicture();
    }

    @GetMapping(value = "/api/users/{user}/profile_picture_small")
    public byte[] getUserProfilePictureSmall (@PathVariable("user") String username) {
        return userRepo.findByUsername(username).getProfilePictureSmall();
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
            User user = userRepo.save(new User(username, password, email, new JWTUtil().generateToken(username), null));
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
    public void recover(@RequestParam String username) {
        User user = userRepo.findByUsername(username);
        if (user.getEmail() != null) {
            String ip = System.getenv("SERVER_IP");
            String url = "https://" + ip + "/public/recover/" + userRepo.setResetUrl(username);
            new EmailHelper().sendMail("Recover your password by pressing the link below:\n\n" + url +"\n\nThis link will be valid until midnight\n Thank you for using this StickIt", user.getEmail(), "Recover Password" );
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

    @RequestMapping(value = "/api/report", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public void addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
        securityFilter.checkJsonForValues(json, new String[] {"report", "username", "message"});
        String username = json.get("username").asText();
        securityFilter.checkUserThrowsException(username);
        String report = json.get("report").asText();
        String message = json.get("message").asText();
        new EmailHelper().sendMail("REPORTED CONTENT/USER: " +  report + "\n\n REPORTED MESSAGE: " + message, "lukasr101@gmail.com", "REPORT");
    }



}
