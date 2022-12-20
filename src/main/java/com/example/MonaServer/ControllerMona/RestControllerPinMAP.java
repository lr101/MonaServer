package com.example.MonaServer.ControllerMona;

import com.example.MonaServer.Controller.RestControllerMona;
import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Mapper.PinMAP;
import com.example.MonaServer.Mapper.StickerTypeMAP;
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
public class RestControllerPinMAP {

    @Autowired
    PinRepo pinRepo;

    @Autowired
    UserRepo userRepo;

    @Autowired
    MonaRepo monaRepo;

    @Autowired
    GroupRepo groupRepo;
    
    @Autowired
    RestControllerMona restControllerMona;

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value ="/api/pins")
    public List<PinMAP> getPins(@RequestParam(required = false) String username) {
        List<PinMAP> list = new ArrayList<>();
        try {
            Group group = groupRepo.getGroup(RestControllerMonaMAP.TORNADO_GROUP_ID);
            securityFilter.checkIfUserIsInPrivateGroup(group);
            group.getPins().forEach(e -> list.add(new PinMAP(e, group)));
        } catch (Exception ignored){};
        try {
            Group group = groupRepo.getGroup(RestControllerMonaMAP.MONA_GROUP_ID);
            securityFilter.checkIfUserIsInPrivateGroup(group);
            group.getPins().forEach(e -> list.add(new PinMAP(e, group)));
        } catch (Exception ignored){};
        if (username == null) {
            return list;
        } else {
            return list.stream().filter(e -> (e.getUsername() != null && e.getUsername().equals(username))).collect(Collectors.toList());
        }

    }

    @GetMapping("/api/pins/{id}")
    public PinMAP getPinById(@PathVariable("id") Long id) {
        Group group = groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id));
        return new PinMAP(restControllerMona.getPinByPinId(id, group.getGroupId()), new GroupDTO(group));
    }

    @GetMapping(value = "/api/pins/{id}/user")
    public String getUsernameOfPin(@PathVariable("id")Long id) {
        Group group = groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id));
        return restControllerMona.getUserOfPin(id, group.getGroupId());
    }

    @GetMapping(value = "/api/pins/{id}/type")
    public StickerTypeMAP getTypeOfPin(@PathVariable("id")Long id) {
        Group group = groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id));
        securityFilter.checkIfUserIsInPrivateGroup(group);
        return new StickerTypeMAP(group);
    }

    @GetMapping(value ="/api/pins-ids")
    public List<Long> getPinIds(@RequestParam(required = false) String username) {
        return this.getPins(username).stream().map(PinMAP::getId).collect(Collectors.toList());
    }

}
