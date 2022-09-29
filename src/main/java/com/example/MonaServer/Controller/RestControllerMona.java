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
import java.io.*;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;

@RestController
public class RestControllerMona {
    @Autowired
    MonaRepo monaRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    VersionRepo versionRepo;

    @Autowired
    TypeRepo typeRepo;

    @Autowired
    UserRepo userRepo;

    @GetMapping(value = "/monas/")
    public List<Mona> getMonas () {
        return (List<Mona>) monaRepo.findAll();
    }

    @PostMapping(value = "/monas/")
    public void addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        double latitude = json.get("latitude").asDouble();
        double longitude = json.get("longitude").asDouble();
        String username = json.get("username").asText();
        Long typeId = json.get("typeId").asLong();
        Date date = new SimpleDateFormat("yyyy-MM-dd").parse(json.get("creationDate").asText());
        if (!addPin(image, latitude, longitude, username, typeId, date)) {
            throw new Exception("Error while adding Pin to user");
        }
    }

    @GetMapping(value = "/monas/{pinId}")
    public Mona getMonaByPinId (@PathVariable("pinId") Long id) {
        return monaRepo.findMonaByPin(pinRepo.findByPinId(id));
    }

    @PutMapping(value = "/monas/{pinId}/")
    public void updatePictureOfMona(@PathVariable("pinId") Long id, @RequestBody ObjectNode json) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        Pin pin = pinRepo.findByPinId(id);
        if (pin != null && image != null) {
            monaRepo.updateMona(image, pin);
            return;
        }
        throw new IllegalArgumentException("Picture could not be updated");
    }

    @DeleteMapping(value = "/monas/{pinId}/")
    public void deleteMonaByPinId (@PathVariable("pinId") Long id) {
        pinRepo.deleteById(id);
        versionRepo.deletePin(id);
    }

    private boolean addPin(byte[] image, double latitude, double longitude, String username, Long typeId, Date date) {
        StickerType type = typeRepo.getStickerTypeById(typeId);
        if (type != null) {
            Pin pin = new Pin(latitude, longitude, date, type);
            Mona mona = new Mona(image, pin);
            mona.setPin(pinRepo.save(mona.getPin()));
            try {
                monaRepo.save(mona);
                userRepo.addPinToCreatedList(username, mona.getPin());
                versionRepo.addPin(mona.getPin().getId());
                return true;
            } catch (Exception ignored) {}
        }
        return false;
    }

}
