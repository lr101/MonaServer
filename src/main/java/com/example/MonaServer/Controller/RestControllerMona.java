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
import org.springframework.http.MediaType;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import java.io.*;
import java.text.SimpleDateFormat;
import java.util.*;

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

    @RequestMapping(value = "/api/monas/", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public Map<String, Object> addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
        if (!json.has("image")) throw new Exception("Error: Field 'image' was not given in request");
        if (!json.has("latitude")) throw new Exception("Error: Field 'latitude' was not given in request");
        if (!json.has("longitude")) throw new Exception("Error: Field 'longitude' was not given in request");
        if (!json.has("username")) throw new Exception("Error: Field 'username' was not given in request");
        if (!json.has("typeId")) throw new Exception("Error: Field 'typeId' was not given in request");
        String username = json.get("username").asText();
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if(!tokenUser.equals(username) && !tokenUser.equals(principalRequestValueAdmin)) throw new Exception("Access denied for this token");
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        double latitude = json.get("latitude").asDouble();
        double longitude = json.get("longitude").asDouble();

        Long typeId = json.get("typeId").asLong();
        Date date = new Date();
        Map<String, Object> map = addPin(image, latitude, longitude, username, typeId, date);
        if(map != null) {
            return map;
        } else {
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
    public Long deleteMonaByPinId (@PathVariable("pinId") Long id, @RequestParam() String username) throws Exception {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if(!tokenUser.equals(username) && !tokenUser.equals(principalRequestValueAdmin)) throw new Exception("Access denied for this token");
        pinRepo.deleteById(id);
        return versionRepo.deletePin(id, new Date());
    }

    private Map<String, Object> addPin(byte[] image, double latitude, double longitude, String username, Long typeId, Date date) {
        StickerType type = typeRepo.getStickerTypeById(typeId);
        if (type != null) {
            Pin pin = new Pin(latitude, longitude, date, type);
            Mona mona = new Mona(image, pin);
            mona.setPin(pinRepo.save(mona.getPin()));
            try {
                monaRepo.save(mona);
                userRepo.addPinToCreatedList(username, mona.getPin());
                Long versionId = versionRepo.addPin(mona.getPin().getId(), date);
                Map<String, Object> map = new HashMap<>();
                map.put("versionId", versionId);
                map.put("pin", mona.getPin());
                return map;
            } catch (Exception ignored) {}
        }
        return null;
    }

}
