package com.example.MonaServer.Mapper;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.DTO.PinDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Pin;
import lombok.Getter;
import lombok.Setter;

import java.util.*;

@Getter
@Setter
public class PinMAP {

    private Long id;

    private double latitude;

    private double longitude;

    private Date creationDate;

    private StickerTypeMAP type;

    private String username;

    public PinMAP(PinDTO pin, GroupDTO groupDTO) {
        this.id =  pin.getId();
        this.latitude = pin.getLatitude();
        this.longitude = pin.getLongitude();
        this.creationDate = pin.getCreationDate();
        this.type = new StickerTypeMAP(groupDTO);
        this.username = pin.getUsername();
    }

    public PinMAP(Pin pin, Group group) {
        this.id =  pin.getId();
        this.latitude = pin.getLatitude();
        this.longitude = pin.getLongitude();
        this.creationDate = pin.getCreationDate();
        this.type = new StickerTypeMAP(group);
        this.username = pin.getUser().getUsername();
    }

    public static List<PinMAP> toDTOList(Map<PinDTO, GroupDTO> pins) {
        List<PinMAP> list = new ArrayList<>();
        pins.forEach((a,b) -> list.add(new PinMAP(a,b)));
        return  list;
    }

    public static Set<PinMAP> toDTOSet(Map<PinDTO, GroupDTO> pins) {
        Set<PinMAP> list = new HashSet<>();
        pins.forEach((a,b) -> list.add(new PinMAP(a,b)));
        return  list;
    }


}
