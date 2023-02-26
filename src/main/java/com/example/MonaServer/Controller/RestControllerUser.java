package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.DTO.MonaDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.DTO.UserDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.EmailHelper;
import com.example.MonaServer.Helper.JWTUtil;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.GroupRepo;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.PinRepo;
import com.example.MonaServer.Repository.UserRepo;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
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

    @Autowired
    PinRepo pinRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    /**
     * Request to get all users
     * @return list of all usernames 
     */
    @GetMapping(value ="/api/users")
    public List<UserDTO> getAllUsers() {
        return UserDTO.toDTOList((List<User>) userRepo.findAll());
    }

    /**
     * Request to get information on a specific user
     * @param username identifies user
     * @return user
     */
    @GetMapping(value = "/api/users/{user}")
    public UserDTO getUser (@PathVariable("user") String username) {
        return new UserDTO(userRepo.findByUsername(username));
    }

    /**
     * Request to update a user.
     * Requesting user can only edit its own data.
     * @param username identifies user
     * @param json body in a json format containing email, password
     * @return login token
     */
    @PutMapping("/api/users/{user}")
    public String putUser(@PathVariable("user") String username, @RequestBody ObjectNode json) {
        securityFilter.checkUserThrowsException(username);
        String email = null;
        String password = null;
        if(json.has("email")) email = json.get("email").asText();
        if(json.has("password")) password = json.get("password").asText();
        userRepo.updateUser(username, password, email, null);
        return userRepo.findByUsername(username).getToken();
    }

    /**
     * Request to delete a user.
     * Requesting user can only delete its own account. 
     * All data including posts and group memberships will be deleted.
     * @param username identifies user
     */
    @DeleteMapping("/api/users/{user}")
    public void deleteUser (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        userRepo.deleteUser(username);
    }

    /**
     * Request to get points of specific user.
     * @param username identifies user
     * @return points
     */
    @GetMapping(value = "/api/users/{user}/points")
    public Long getUserPoints (@PathVariable("user") String username) {
        if (userRepo.existsById(username)) throw  new NoSuchElementException("ERROR: User with username: " + username + " does not exist");
        return userRepo.getUserPoints(username);
    }

    /**
     * Request to get own email.
     * Requesting user can see its own data.
     * @param username identifies user
     * @return email
     */
    @GetMapping(value = "/api/users/{user}/email")
    public String getUserEmail (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        return userRepo.findByUsername(username).getEmail();
    }

    /**
     * Request to get own groups.
     * Requesting user can only see its own groups.
     * @param username identifies user
     * @return set of user groups
     */
    @GetMapping(value = "/api/users/{user}/groups")
    public Set<GroupDTO> getUserGroups (@PathVariable("user") String username) {
        securityFilter.checkUserThrowsException(username);
        return GroupDTO.toDTOSet(groupRepo.getGroupsOfUser(userRepo.findByUsername(username)), groupRepo);
    }

    /**
     * Request to get all sets of pins of the requested groups.
     * Requesting user can only access groups that are public or is a member of.
     * @param ids is a string containing the requested group ids. Format: /api/groups?ids=0-1-2-3-4-5-6-...
     * @return List of sets of pins in the order of the requested ids
     */
    @GetMapping(value = "/api/users/{user}/selected-pins")
    public List<Set<PinDTO>> getPinsOfMultipleGroups(@RequestParam String ids, @PathVariable String user) {
        List<Long> idList = Arrays.stream(ids.split("-")).map(Long::parseLong).toList();
        List<Set<PinDTO>> list = new ArrayList<>();
        for (Long groupId : idList) {
            Group group = groupRepo.getGroup(groupId);
            try {
                securityFilter.checkIfUserIsInPrivateGroup(group);
                list.add(PinDTO.toDTOSet(group.getPins()));
            } catch (Exception ignored){}
        }
        return list;
    }

    /**
     * Request to get pins of a specif user.
     * Requesting user can only see the pins of the user of pins posted in a shared group.
     * @param username identifies user
     * @return list of pin ids
     */
    @GetMapping(value = "/api/users/{user}/pins")
    public List<Map<String, Object>> getUserPins (@PathVariable("user") String username) {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        return pinRepo.getPinsOfUserInGroupsOfTokenUser(username, tokenUser);
    }

    /**
     * Request to get pins of a user in a specif group.
     * Requesting user must be a member of the group.
     * @param username identifies user
     * @param groupId identifies group
     * @return set of private pins
     */
    @GetMapping(value = "/api/users/{user}/pins/{groupId}")
    public Set<PinDTO> getUserPinsByGroup (@PathVariable("user") String username, @PathVariable("groupId") Long groupId) {
        securityFilter.checkUserInGroupThrowsException(groupRepo.getGroup(groupId));
        return PinDTO.toDTOSet(groupRepo.getPinsOfUserInGroup(groupId, username));
    }

    /**
     * Request to update profile picture of user.
     * Requesting user can only edit its own profile picture.
     * @param username identifies user
     * @param json body in json format must contain key 'image'
     * @return profile image as byte array
     * @throws IOException when reader cannot parse image
     */
    @PutMapping(value = "/api/users/{user}/profile_picture")
    public byte[] putUserProfilePicture (@PathVariable("user") String username, @RequestBody ObjectNode json) throws IOException {
        securityFilter.checkUserThrowsException(username);
        securityFilter.checkJsonForValues(json, new String[] {"image"});
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        return userRepo.updateProfilePicture(username, reader.readValue(json.get("image")));
    }

    /**
     * Request to get full sized profile picture of a user
     * @param username identifies user
     * @return profile image as byte array
     */
    @GetMapping(value = "/api/users/{user}/profile_picture")
    public byte[] getUserProfilePicture (@PathVariable("user") String username) {
        return userRepo.findByUsername(username).getProfilePicture();
    }

    /**
     * Request to get reduced sized profile picure of a user
     * @param username identifies user
     * @return profile image as byte array
     */
    @GetMapping(value = "/api/users/{user}/profile_picture_small")
    public byte[] getUserProfilePictureSmall (@PathVariable("user") String username) {
        return userRepo.findByUsername(username).getProfilePictureSmall();
    }

    //#################### Authentication routes ##########################

    /**
     * Request to signup a new user by creating a new account.
     * Username must be unique.
     * @param json body in json format must contain keys 'email', 'password', 'username'
     * @return login token
     */
    @PostMapping("/signup")
    public String postUser(@RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"email", "password", "username"});
        String email = json.get("email").asText();
        String password = json.get("password").asText();
        String username = json.get("username").asText();
        if (userRepo.existsById(username)) {
            User user = userRepo.save(new User(username, password, email, new JWTUtil().generateToken(username, password), null));
            return user.getToken();
        }
        throw new IllegalArgumentException("User with username: " + username + " already exists");
    }

    /**
     * Request to sign-in.
     * Password must match password of username.
     * @param json body in json format must contain keys 'password', 'username'
     * @return login token
     */
    @PostMapping(value = "/login")
    public String login(@RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"password", "username"});
        String password = json.get("password").asText();
        String username = json.get("username").asText();
        User user = userRepo.findByUsername(username);
        if(user.getPassword().equals(password)) {
            String token = new JWTUtil().generateToken(username, user.getPassword());
            userRepo.updateUser(username, null, null, token);
            return token;
        }
        throw new IllegalArgumentException("ERROR: Wrong Password");
    }

    /**
     * Request to send a recovery email to email address of user
     * @param username identifies user
     */
    @GetMapping(value = "/recover")
    public void recover(@RequestParam String username) {
        User user = userRepo.findByUsername(username);
        if (user.getEmail() != null) {
            String ip = System.getenv("SERVER_IP");
            String url = "https://" + ip + "/public/recover/" + userRepo.setResetUrl(username);
            new EmailHelper().sendMail("Recover your password by pressing the link below:\n\n" +
                            url +
                            "\n\nThis link will be valid until midnight\n" +
                            "Thank you for using this StickIt", user.getEmail(), "Recover Password" );
        }
    }

    /**
     * Request to report a user, content or just send a message
     * @param json body in json format must contain key
     *             'report'     (reported content),
     *             'username'   (reporting user),
     *             'message'    (reported msg)
     */
    @RequestMapping(value = "/api/report", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public void addNewPinToUser(@RequestBody ObjectNode json) {
        securityFilter.checkJsonForValues(json, new String[] {"report", "username", "message"});
        String username = json.get("username").asText();
        securityFilter.checkUserThrowsException(username);
        String report = json.get("report").asText();
        String message = json.get("message").asText();
        new EmailHelper().sendMail("REPORTED CONTENT/USER: " +  report + "\n\nREPORTED MESSAGE: " + message, "lukasr101@gmail.com", "REPORT");
    }



}
