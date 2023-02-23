package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.DTO.MonaDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

import javax.transaction.Transactional;
import java.io.IOException;
import java.util.*;

@RestController
@Transactional
public class RestControllerMona {
    @Autowired
    MonaRepo monaRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    UserRepo userRepo;

    @Autowired
    GroupRepo groupRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    /**
     * Returns a complete set of pins of a group identified by [groupId].
     * The requesting user must be a member of the group.
     * @param groupId identifies the group
     * @return complete set of pins containing the pin id, latitude, longitude, creation date, creation user
     */
    @GetMapping("/api/groups/{groupId}/pins")
    public Set<PinDTO> getPinsOfGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserInGroupThrowsException(group);
        return PinDTO.toDTOSet(group.getPins());
    }

    /**
     * Adds a new pin to a group.
     * The requesting user must be a member of the group.
     * @param json The body of the request must contain the following keys in a map format:
     *             'image', 'latitude', 'longitude', 'username', 'groupId'
     * @return Pin containing the pin id, latitude, longitude, creation date, creation user
     * @throws IOException if the 'image' could not be parsed
     */
    @RequestMapping(value = "/api/pins", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public PinDTO addNewPinToGroup(@RequestBody ObjectNode json) throws IOException {
        securityFilter.checkJsonForValues(json, new String[] {"image", "latitude", "longitude", "username", "groupId"});
        String username = json.get("username").asText();
        securityFilter.checkUserThrowsException(username);
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        double latitude = json.get("latitude").asDouble();
        double longitude = json.get("longitude").asDouble();
        Long groupId = json.get("groupId").asLong();
        Date date = new Date();
        return addPin(image, latitude, longitude, username, groupId, date);
    }

    /**
     * Request for a single pin.
     * The requesting user must be a member of the group containing the pin or must be the creation user.
     * @param id identifies the requested pin
     * @return Pin containing the pin id, latitude, longitude, creation date, creation user |
     * Group containing the group id, visibility, group name
     */
    @GetMapping(value = "/api/pins/{pinId}")
    public Map<String, Object> getPinByPinId(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        Group group = groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id));
        securityFilter.checkPinIsInGroupOfUserThrowsException(group, pin);
        Map<String, Object> json = new HashMap<>();
        json.put("pin", new PinDTO(pin));
        json.put("group", GroupDTO.getPrivateDTO(group));
        return json;
    }

    /**
     * Request to update an image of a pin.
     * The requesting user must be the creator of the pin.
     * @param id identifies the pin
     * @param json is the body in a json format of the request containing the key 'image'
     * @throws IOException if the 'image' could not be parsed
     */
    @PutMapping(value = "/api/pins/{pinId}")
    public void updatePin(@PathVariable("pinId") Long id, @RequestBody ObjectNode json) throws IOException {
        securityFilter.checkJsonForValues(json, new String[] {"image"});
        securityFilter.checkUserIsPinCreator(pinRepo.findByPinId(id));
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        if (image != null) {
            monaRepo.updateMona(image, id);
            return;
        }
        throw new IllegalArgumentException("Picture could not be updated");
    }

    /**
     * Request to delete a pin.
     * The requesting user must be the creator of the pin.
     * @param id identifies the pin
     */
    @DeleteMapping(value = "/api/pins/{pinId}")
    public void deletePin(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkUserIsPinCreator(pin);
        pinRepo.deleteById(id);
    }

    /**
     * Request to get the username of the creator of a specific pin.
     * The requesting user must be a member of the group containing the pin or must be the creation user.
     * @param id identifies the pin
     * @return username of the creation user
     */
    @GetMapping(value = "/api/pins/{pinId}/user")
    public String getUserOfPin(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pin);
        return (pin.getUser() != null ? pin.getUser().getUsername() : null);
    }

    /**
     * Request to get the image of a specific pin.
     * The requesting user must be a member of the group containing the pin or must be the creation user.
     * @param id identifies the pin
     * @return image as byte array
     */
    @GetMapping(value = "/api/pins/{pinId}/image")
    public byte[] getImageOfPin(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pin);
        return monaRepo.getMonaFromPinId(id).getImage();
    }

    /**
     * Private method to handle adding a new pin
     * @param image byte array containing image data
     * @param latitude double
     * @param longitude double
     * @param username creation user
     * @param groupId identifier for group where pin will be added to
     * @param date creation date
     * @return created pin
     */
    private PinDTO addPin(byte[] image, double latitude, double longitude, String username, Long groupId, Date date) {
        Group group = groupRepo.getGroup(groupId);
        User user = userRepo.findByUsername(username);
        Pin pin = monaRepo.createMona(image, latitude, longitude, user, date);
        group.addPin(pin);
        groupRepo.save(group);
        return new PinDTO(pin);
    }

}
