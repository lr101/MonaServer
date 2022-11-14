package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.MonaDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.*;
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

    @GetMapping(value = "/api/monas")
    public List<MonaDTO> getMonas () {
        securityFilter.checkAdminOnlyThrowsException();
        return MonaDTO.toDTOList((List<Mona>) monaRepo.findAll());
    }

    @RequestMapping(value = "/api/monas", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public PinDTO addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
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

    @GetMapping(value = "/api/monas/{pinId}")
    public MonaDTO getMonaByPinId (@PathVariable("pinId") Long id) {
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo, id);
        return new MonaDTO(monaRepo.getMonaFromPinId(id));
    }

    @PutMapping(value = "/api/monas/{pinId}")
    public void updatePictureOfMona(@PathVariable("pinId") Long id, @RequestBody ObjectNode json) throws Exception {
        securityFilter.checkJsonForValues(json, new String[] {"image"});
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo, id);
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

    @DeleteMapping(value = "/api/monas/{pinId}")
    public void deleteMonaByPinId (@PathVariable("pinId") Long id) {
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo, id);
        securityFilter.checkUserIsPinCreator(pinRepo.findByPinId(id));
        pinRepo.deleteById(id);
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
