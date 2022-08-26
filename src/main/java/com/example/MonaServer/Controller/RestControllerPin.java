package com.example.MonaServer.Controller;

import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.io.IOException;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.stream.Collectors;

@RestController
public class RestControllerPin {

    @Autowired
    PinRepo pinRepo;

    @Autowired
    UserRepo userRepo;

    @Autowired
    MonaRepo monaRepo;

    @Autowired
    TypeRepo typeRepo;

    @Autowired
    VersionRepo versionRepo;

    Config config = new Config();


    @GetMapping(value ="/pins/")
    public List<Pin> getAllPins() {
        return (List<Pin>) pinRepo.findAll();
    }

    /**
     * @param username username of user account
     * @param type
     *  0: all pins created or found by {user}
     *  1: all pins created by {user}
     *  2: all pins found by {user}
     *  3: all pins not created or found by {user}
     * @return List of pins
     */
    @GetMapping(value = "/users/{user}/pins")
    public Set<Pin> getPinsOfUser (@PathVariable("user") String username, @RequestParam int type) {
        switch (type) {
            case 0 : return userRepo.getMappedPins(username);
            case 1 : return userRepo.findByUsername(username).getCreatedPins();
            case 2 : return userRepo.findByUsername(username).getFoundPins();
            case 3 :
                Set<Pin> userPins = userRepo.getMappedPins(username);
                return ((List<Pin>) pinRepo.findAll()).stream().filter(p -> !userPins.contains(p)).collect(Collectors.toSet());
        }
        throw new IllegalArgumentException("type or username does not exist");
    }





    @PutMapping(value = "/users/{user}/pins")
    public void addExistingPinToUser(@PathVariable("user") String username, @RequestBody ObjectNode json) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        Long id = json.get("id").asLong();
        Pin pin = pinRepo.findByPinId(id);
        if (pin != null) {
            monaRepo.updateMona(image, pin);
            userRepo.addPinToFoundList(username,pin);
            return;
        }
        throw new IllegalArgumentException("Sticker could not be added");
    }

    @GetMapping(value = "/pins/{id}/user")
    public String getUsernameOfPin(@PathVariable("id")Long id) {
        Pin pin = pinRepo.findByPinId(id);
        return userRepo.findUserByPin(pin).getUsername();
    }

    @PostMapping(value = "/users/{user}/pins")
    public void addNewPinToUser(@PathVariable("user") String username, @RequestBody ObjectNode json) throws ParseException, IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        double latitude = json.get("latitude").asDouble();
        double longitude = json.get("longitude").asDouble();
        Long typeId = json.get("typeId").asLong();
        Date date = new SimpleDateFormat("yyyy-MM-dd").parse(json.get("creationDate").asText());
        Optional<StickerType> type = typeRepo.findById(typeId);
        if (type.isPresent()) {
            Pin pin = new Pin(latitude, longitude, date, type.get());
            Mona mona = new Mona(image, pin);
            mona.setPin(pinRepo.save(mona.getPin()));
            monaRepo.save(mona);
            userRepo.addPinToCreatedList(username, mona.getPin());
            versionRepo.addPin(mona.getPin().getId());
            userRepo.updateUser(username, config.P_NEW_PIN);
        } else {
            throw new IllegalArgumentException("Sticker could not be added");
        }
    }

    /**
     *
     * @param id
     * @param username method returns null when the pin is created by this user
     * @return
     */
    @GetMapping("/pins/{id}")
    public Pin getPinById(@PathVariable("id") Long id, @RequestParam(required = false) String username) {
        if (username == null) {
            return pinRepo.findByPinId(id);
        } else {
            Pin pin = pinRepo.findByPinId(id);
            if(!userRepo.getMappedPins(username).contains(pin)) {
                return pin;
            }
        }
        return null;
    }



    @PostMapping(value="pins/{id}/type")
    public Pin changeTypeOfPin(@PathVariable("id") Long id,  @RequestBody ObjectNode json) {
        Pin pin = pinRepo.findByPinId(id);
        pin.setType(typeRepo.findById(json.get("typeId").asLong()).get());
        pinRepo.save(pin);
        return pin;
    }

}
