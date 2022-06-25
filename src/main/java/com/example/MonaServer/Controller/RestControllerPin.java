package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.ImageProcessor;
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
    public ArrayList<Pin> getAllPins() {
        return (ArrayList<Pin>) pinRepo.findAll();
    }

    @GetMapping(value ="/pins/{user}/radius")
    public List<Pin> getAllPinsWithoutUserPinsInRadius(@PathVariable("user") String username, @RequestParam double latitude, @RequestParam double longitude) {
        return pinRepo.findOtherPinsInRadius(latitude, longitude, userRepo.getMappedPins(username));
    }

    @GetMapping(value ="/pins/{user}/radiusCount")
    public int getAllPinsWithoutUserPinsInRadiusCount(@PathVariable("user") String username, @RequestParam double latitude, @RequestParam double longitude) {
        return pinRepo.findOtherPinsInRadius(latitude, longitude, userRepo.getMappedPins(username)).size();
    }

    @GetMapping(value ="/pins/{user}/check")
    public boolean getAllPinsMissing(@PathVariable("user") String username, @RequestBody ObjectNode json) throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<List<Long>>() {});
        List<Long> ids = reader.readValue(json.get("ids"));
        List<Long> existingIds = new ArrayList<>();
        getPinsOfUser(username, json.get("type").asInt()).forEach(e -> existingIds.add(e.getId()));
        boolean t = false;
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
    public List<Long> getAllPinsRemoved(@PathVariable("user") String username, @RequestBody ObjectNode json) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<List<Long>>() {});
        List<Long> ids = reader.readValue(json.get("ids"));
        return ids.stream().filter(e -> filter(e, getPinsOfUser(username, json.get("type").asInt()))).collect(Collectors.toList());
    }

    private boolean filter(Long id, List<Pin> pins) {
        for (Pin pin : pins) {
            if ((long)id == pin.getId()) {
                return true;
            }
        }
        return false;
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
    public List<Pin> getPinsOfUser (@PathVariable("user") String username, @RequestParam int type) {
        switch (type) {
            case 0 : return userRepo.getMappedPins(username);
            case 1 : return userRepo.findByUsername(username).getCreatedPins();
            case 2 : return userRepo.findByUsername(username).getFoundPins();
            case 3 :
                List<Pin> userPins = userRepo.getMappedPins(username);
                return ((List<Pin>) pinRepo.findAll()).stream().filter(p -> !userPins.contains(p)).collect(Collectors.toList());
        }
        throw new IllegalArgumentException("type or username does not exist");
    }

    @GetMapping(value = "/monas")
    public Mona getMonaByPinId (@RequestParam Long id) {
        return monaRepo.findMonaByPin(pinRepo.findByPinId(id));
    }

    /*@PutMapping(value = "/users/{user}/pins/")
    public List<Pin> addExistingPinToUser(@PathVariable("user") String username,@RequestBody Mona mona) {
        List<Pin> pins = getAllPinsWithoutUserPinsInRadius(username, mona.getPin().getLatitude(), mona.getPin().getLongitude());
        pins.sort((a,b) -> sort(a,b,mona.getPin()));
        monaRepo.updateMona(mona.getImage(), pins.get(0));
        return userRepo.addPinToFoundList(username, mona.getPin());
    }*/

    @PostMapping(value = "/users/{user}/pins")
    public List<Pin> addNewPinToUser(@PathVariable("user") String username, @RequestBody ObjectNode json, @RequestParam boolean newSticker) throws ParseException, IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        double latitude = json.get("latitude").asDouble();
        double longitude = json.get("longitude").asDouble();
        Date date = new SimpleDateFormat("yyyy-MM-dd").parse(json.get("creationDate").asText());
        StickerType type = ImageProcessor.getStickerType(image, typeRepo);
        if (newSticker) {
            Pin pin = new Pin(latitude, longitude, date, type);
            Mona mona = new Mona(image, pin);

            mona.setPin(pinRepo.save(mona.getPin()));
            monaRepo.save(mona);
            return userRepo.addPinToCreatedList(username, mona.getPin());
        } else {
            List<Pin> pins = getAllPinsWithoutUserPinsInRadius(username, latitude, longitude);
            if (pins.size() > 0) {
                pins.sort((a, b) -> sort(a, b, latitude, longitude));
                monaRepo.updateMona(image, pins.get(0));
                return userRepo.addPinToFoundList(username, pins.get(0));
            }
        }
        throw new IllegalArgumentException("Sticker could not be added");
    }

    private int sort (Pin a, Pin b, double latitude, double longitude) {
        double ai = PinRepoImpl.calcDistance(a.getLatitude(), a.getLongitude(), latitude, longitude);
        double bi = PinRepoImpl.calcDistance(b.getLatitude(), b.getLongitude(), latitude, longitude);
        if (ai < bi) {
            return (int) (bi - ai);
        } else {
            return (int) (ai - bi);
        }
    }

    //working
    @PostMapping("/pins/")
    public Mona postPin(@RequestBody Mona mona) {
        return monaRepo.save(mona);
    }

    @DeleteMapping("/pins/{id}")
    public void deletePin (@PathVariable("id") Long id) {
        pinRepo.deletePin(id);
    }
}
