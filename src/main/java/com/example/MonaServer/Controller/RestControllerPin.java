package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.*;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
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

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value ="/api/pins")
    public List<PinDTO> getPins(@RequestParam(required = false) String username) {
        List<Pin> pins = (List<Pin>) pinRepo.findAll();
        if (username == null) {
            return PinDTO.toDTOList(pins);
        } else {
            return PinDTO.toDTOList(pins.stream().filter(e -> e.getUser().getUsername().equals(username)).collect(Collectors.toList()));
        }

    }

    @GetMapping("/api/pins/{id}")
    public PinDTO getPinById(@PathVariable("id") Long id) {
        return new PinDTO(pinRepo.findByPinId(id));
    }

    @GetMapping(value = "/api/pins/{id}/user")
    public String getUsernameOfPin(@PathVariable("id")Long id) {
        return pinRepo.findByPinId(id).getUser().getUsername();
    }

    @GetMapping(value = "/api/pins/{id}/type")
    public StickerType getTypeOfPin(@PathVariable("id")Long id) {
        Pin pin = pinRepo.findByPinId(id);
        return pin.getType();
    }

    @PutMapping(value="/api/pins/{id}/type")
    public PinDTO changeTypeOfPin(@PathVariable("id") Long id,@RequestParam String username, @RequestBody ObjectNode json) {
        securityFilter.checkUserThrowsException(username);
        if (!json.has("typeId")) throw new IllegalArgumentException("Error: Field typeId was not given in request");
        Long typeId = json.get("typeId").asLong();
        Pin pin = pinRepo.findByPinId(id);
        Optional<StickerType> type = typeRepo.findById(typeId);
        if (type.isPresent() && pin != null) {
            pin.setType(type.get());
            return new PinDTO(pinRepo.save(pin));
        }
        throw new IllegalArgumentException("Error: Pin or StickerType does not exist");
    }

    @GetMapping(value ="/api/pins-ids")
    public List<Long> getPinIds(@RequestParam(required = false) String username) {
        List<Pin> pins = (List<Pin>) pinRepo.findAll();
        if (username == null) {
            return pins.stream().map(Pin::getId).collect(Collectors.toList());
        } else {
            return pins.stream().filter(e -> e.getUser().getUsername().equals(username)).map(Pin::getId).collect(Collectors.toList());
        }

    }

}
