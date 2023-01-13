package com.example.MonaServer.ControllerMona;

import com.example.MonaServer.Controller.RestControllerMona;
import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Mapper.MonaMAP;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Mapper.PinMAP;
import com.example.MonaServer.Repository.GroupRepo;
import com.example.MonaServer.Repository.MonaRepo;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.*;

@RestController
public class RestControllerMonaMAP {

    public static final Long MONA_GROUP_ID = 0L;
    public static final Long MONA_APP_ID = 0L;
    public static final Long TORNADO_GROUP_ID = 1L;
    public static final Long TORNADO_APP_ID = 1L;

    @Autowired
    RestControllerMona restControllerMona;

    @Autowired
    GroupRepo groupRepo;

    @Autowired
    MonaRepo monaRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    @RequestMapping(value = "/api/monas", method = RequestMethod.POST, produces = MediaType.APPLICATION_JSON_VALUE)
    public PinMAP addNewPinToUser(@RequestBody ObjectNode json) throws Exception {
        long typeId = json.get("typeId").asLong();
        long groupId =  typeId == 0 ? MONA_GROUP_ID : TORNADO_GROUP_ID;
        json.put("groupId",groupId);
        PinDTO pinDTO = restControllerMona.addNewPinToGroup(json);
        return new PinMAP(pinDTO, new GroupDTO(groupRepo.getGroup(groupId)));
    }

    @GetMapping(value = "/api/monas/{pinId}")
    public MonaMAP getMonaByPinId (@PathVariable("pinId") Long id) {
        Mona mona = monaRepo.getMona(id);
        securityFilter.checkPinIsInGroupOfUserThrowsException(groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)), mona.getPin());
        return new MonaMAP(mona, groupRepo.getGroup(monaRepo.getGroupIdFromPinId(id)));
    }

    @DeleteMapping(value = "/api/monas/{pinId}")
    public void deleteMonaByPinId (@PathVariable("pinId") Long id) {
        restControllerMona.deletePin(id);
    }

}
