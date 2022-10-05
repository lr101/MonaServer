package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.*;

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

    @Value("${AUTH_TOKEN_ADMIN}")
    private String principalRequestValueAdmin;

    @GetMapping(value ="/api/pins/")
    public List<Pin> getPins() {
        return (List<Pin>) pinRepo.findAll();
    }

    /**
     *
     * @param id
     * @param username method returns null when the pin is created by this user
     * @return
     */
    @GetMapping("/api/pins/{id}")
    @ResponseBody
    public Pin getPinById(@PathVariable("id") Long id, @RequestParam(required = false) String username) {
        if (username == null) {
            return pinRepo.findByPinId(id);
        } else {
            Pin pin = pinRepo.findByPinId(id);
            if(userRepo.getMappedPins(username).contains(pin)) {
                return pin;
            }
        }
        return null;
    }

    @GetMapping(value = "/api/pins/{id}/user/")
    public String getUsernameOfPin(@PathVariable("id")Long id) {
        Pin pin = pinRepo.findByPinId(id);
        return userRepo.findUserByPin(pin).getUsername();
    }

    @GetMapping(value = "/api/pins/{id}/type/")
    public StickerType getTypeOfPin(@PathVariable("id")Long id) {
        Pin pin = pinRepo.findByPinId(id);
        return pin.getType();
    }

    @PutMapping(value="pins/{id}/type")
    public Pin changeTypeOfPin(@PathVariable("id") Long id,@RequestParam String username, @RequestBody ObjectNode json) throws Exception {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if(!tokenUser.equals(username) && !tokenUser.equals(principalRequestValueAdmin)) throw new Exception("Access denied for this token");
        Pin pin = pinRepo.findByPinId(id);
        Long typeId = null;
        if (json.has("typeId")) typeId = json.get("typeId").asLong();
        if (typeId == null) throw new Exception("Error: Field typeId was not given in request");
        Optional<StickerType> type = typeRepo.findById(typeId);
        if (type.isPresent() && pin != null) {
            pin.setType(type.get());
            pinRepo.save(pin);
            return pin;
        }
        throw new Exception("Error: Pin or StickerType does not exist");
    }

}
