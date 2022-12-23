package com.example.MonaServer.Controller;

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
import java.util.*;

@RestController
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

    @GetMapping("/api/groups/{groupId}/pins")
    public Set<PinDTO> getPinsOfGroup(@PathVariable Long groupId) {
        Group group = groupRepo.getGroup(groupId);
        securityFilter.checkUserInGroupThrowsException(group);
        return PinDTO.toDTOSet(group.getPins());
    }

    @RequestMapping(value = "/api/pins", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public PinDTO addNewPinToGroup(@RequestBody ObjectNode json) throws Exception {
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

    @GetMapping(value = "/api/pins/{pinId}")
    public PinDTO getPinByPinId(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pin);
        return new PinDTO(pin);
    }

    @PutMapping(value = "/api/pins/{pinId}")
    public void updatePin(@PathVariable("pinId") Long id, @RequestBody ObjectNode json) throws Exception {
        securityFilter.checkJsonForValues(json, new String[] {"image"});
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pinRepo.findByPinId(id));
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

    @DeleteMapping(value = "/api/pins/{pinId}")
    public void deletePin(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pin);
        securityFilter.checkUserIsPinCreator(pin);
        pinRepo.deleteById(id);
    }

    @GetMapping(value = "/api/pins/{pinId}/user")
    public String getUserOfPin(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pin);
        return (pin.getUser() != null ? pin.getUser().getUsername() : null);
    }

    @GetMapping(value = "/api/pins/{pinId}/image")
    public byte[] getImageOfPin(@PathVariable("pinId") Long id) {
        Pin pin = pinRepo.findByPinId(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), pin);
        return monaRepo.getMonaFromPinId(id).getImage();
    }

    private PinDTO addPin(byte[] image, double latitude, double longitude, String username, Long groupId, Date date) {
        Group group = groupRepo.getGroup(groupId);
        User user = userRepo.findByUsername(username);
        Pin pin = monaRepo.createMona(image, latitude, longitude, user, date);
        group.addPin(pin);
        groupRepo.save(group);
        return new PinDTO(pin);
    }

}
