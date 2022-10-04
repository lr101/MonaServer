package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.*;
import java.io.*;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.Map;

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

    @Value("${AUTH_TOKEN_ADMIN}")
    private String principalRequestValueAdmin;

    @GetMapping(value = "/api/monas/")
    public List<Mona> getMonas () {
        return (List<Mona>) monaRepo.findAll();
    }

    @PostMapping(value = "/api/monas/")
    public void addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
        if (!json.has("image")) throw new Exception("Error: Field 'image' was not given in request");
        if (!json.has("latitude")) throw new Exception("Error: Field 'latitude' was not given in request");
        if (!json.has("longitude")) throw new Exception("Error: Field 'longitude' was not given in request");
        if (!json.has("username")) throw new Exception("Error: Field 'username' was not given in request");
        if (!json.has("typeId")) throw new Exception("Error: Field 'typeId' was not given in request");
        if (!json.has("creationDate")) throw new Exception("Error: Field 'creationDate' was not given in request");
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

    @GetMapping(value = "/api/monas/{pinId}")
    public Mona getMonaByPinId (@PathVariable("pinId") Long id) {
        return monaRepo.findMonaByPin(pinRepo.findByPinId(id));
    }

    @PutMapping(value = "/api/monas/{pinId}/")
    public void updatePictureOfMona(@PathVariable("pinId") Long id, @RequestBody ObjectNode json) throws Exception {
        if (!json.has("image")) throw new Exception("Error: Field 'image' was not given in request");
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

    @DeleteMapping(value = "/api/monas/{pinId}")
    public void deleteMonaByPinId (@PathVariable("pinId") Long id, @RequestParam() String username, @RequestHeader Map<String, String> headers) throws Exception {
        if(headers.containsKey(Config.API_KEY_AUTH_HEADER_NAME_ADMIN) &&                                        //request header has admin API Key
                headers.get(Config.API_KEY_AUTH_HEADER_NAME_ADMIN).equals(principalRequestValueAdmin) ||        //check if admin API key is correct
                userRepo.getMappedPins(username).contains(pinRepo.findByPinId(id))){                            //user is the creator of this pin

            pinRepo.deleteById(id);
            versionRepo.deletePin(id);
        } else {
            throw new Exception("Access denied. Only admins and the user, who created this pin are able to delete it");
        }

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
