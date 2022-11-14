package com.example.MonaServer.Controller;

import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
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
    GroupRepo groupRepo;


    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping("/api/pins/{id}")
    public PinDTO getPinById(@PathVariable("id") Long id) {
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo, id);
        return new PinDTO(pinRepo.findByPinId(id));
    }

    @GetMapping(value = "/api/pins/{id}/user")
    public String getUsernameOfPin(@PathVariable("id")Long id) {
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo, id);
        User user = pinRepo.findByPinId(id).getUser();
        return user != null ? user.getUsername() : null;
    }

}
