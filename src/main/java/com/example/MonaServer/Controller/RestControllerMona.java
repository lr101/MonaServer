package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.MonaDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.StickerType;
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
    TypeRepo typeRepo;

    @Autowired
    UserRepo userRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value = "/api/monas")
    public List<MonaDTO> getMonas () {
        return MonaDTO.toDTOList((List<Mona>) monaRepo.findAll());
    }

    @RequestMapping(value = "/api/monas", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public PinDTO addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
        if (!json.has("image")) throw new Exception("Error: Field 'image' was not given in request");
        if (!json.has("latitude")) throw new Exception("Error: Field 'latitude' was not given in request");
        if (!json.has("longitude")) throw new Exception("Error: Field 'longitude' was not given in request");
        if (!json.has("username")) throw new Exception("Error: Field 'username' was not given in request");
        if (!json.has("typeId")) throw new Exception("Error: Field 'typeId' was not given in request");
        String username = json.get("username").asText();
        securityFilter.checkUserThrowsException(username);
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        double latitude = json.get("latitude").asDouble();
        double longitude = json.get("longitude").asDouble();
        Long typeId = json.get("typeId").asLong();
        Date date = new Date();
        return addPin(image, latitude, longitude, username, typeId, date);
    }

    @GetMapping(value = "/api/monas/{pinId}")
    public MonaDTO getMonaByPinId (@PathVariable("pinId") Long id) {
        return new MonaDTO(monaRepo.getMonaFromPinId(id));
    }

    @PutMapping(value = "/api/monas/{pinId}")
    public void updatePictureOfMona(@PathVariable("pinId") Long id, @RequestBody ObjectNode json) throws Exception {
        if (!json.has("image")) throw new Exception("Error: Field 'image' was not given in request");
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
    public void deleteMonaByPinId (@PathVariable("pinId") Long id, @RequestParam() String username) {
        securityFilter.checkUserThrowsException(username);
        monaRepo.deleteMona(id);
    }

    private PinDTO addPin(byte[] image, double latitude, double longitude, String username, Long typeId, Date date) {
        StickerType type = typeRepo.getStickerTypeById(typeId);
        User user = userRepo.findByUsername(username);
        return new PinDTO(monaRepo.createMona(image, latitude, longitude, user, type, date));
    }

}
