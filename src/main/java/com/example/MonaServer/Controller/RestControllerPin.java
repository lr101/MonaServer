package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
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

    @GetMapping(value ="/pins/")
    public List<Pin> getPins() {
        return (List<Pin>) pinRepo.findAll();
    }

    /**
     *
     * @param id
     * @param username method returns null when the pin is created by this user
     * @return
     */
    @GetMapping("/pins/{id}")
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

    @GetMapping(value = "/pins/{id}/user/")
    public String getUsernameOfPin(@PathVariable("id")Long id) {
        Pin pin = pinRepo.findByPinId(id);
        return userRepo.findUserByPin(pin).getUsername();
    }

    @GetMapping(value = "/pins/{id}/type/")
    public StickerType getTypeOfPin(@PathVariable("id")Long id) {
        Pin pin = pinRepo.findByPinId(id);
        return pin.getType();
    }

    @PutMapping(value="pins/{id}/type/")
    public Pin changeTypeOfPin(@PathVariable("id") Long id,  @RequestBody ObjectNode json) throws Exception {
        Pin pin = pinRepo.findByPinId(id);
        Optional<StickerType> type = typeRepo.findById(json.get("typeId").asLong());
        if (type.isPresent() && pin != null) {
            pin.setType(type.get());
            pinRepo.save(pin);
            return pin;
        }
        throw new Exception("Error: Pin or StickerType does not exist");
    }

}
