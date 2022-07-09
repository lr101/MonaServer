package com.example.MonaServer.Controller;

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
        } else {
            throw new IllegalArgumentException("Sticker could not be added");
        }
    }

    @DeleteMapping("/pins/{id}")
    public void deletePin (@PathVariable("id") Long id) {
        monaRepo.deleteById(id);
    }

    /*@GetMapping(value ="/pins/{user}/check")
    public boolean getAllPinsMissing(@PathVariable("user") String username, @RequestBody ObjectNode json) throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<List<Long>>() {});
        List<Long> ids = reader.readValue(json.get("ids"));
        List<Long> existingIds = new ArrayList<>();
        getPinsOfUser(username, json.get("type").asInt()).forEach(e -> existingIds.add(e.getId()));
        for (Long id : ids) {
            for (Long id2 : existingIds) {
                if (Objects.equals(id, id2)) {
                    ids.remove(id);
                    existingIds.remove(id2);
                }
            }
        }
        if (ids.size() == 0 && existingIds.size() == 0) {
            return true;
        } else {
            throw new Exception("Pins are not consistent");
        }
    }

    @GetMapping(value ="/pins/{user}/removed")
    public Set<Long> getAllPinsRemoved(@PathVariable("user") String username, @RequestBody ObjectNode json) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<List<Long>>() {});
        List<Long> ids = reader.readValue(json.get("ids"));
        return ids.stream().filter(e -> filter(e, getPinsOfUser(username, json.get("type").asInt()))).collect(Collectors.toSet());
    }

    private boolean filter(Long id, Set<Pin> pins) {
        for (Pin pin : pins) {
            if ((long)id == pin.getId()) {
                return true;
            }
        }
        return false;
    }*/
}
