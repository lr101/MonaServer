package com.example.MonaServer.Mapper;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import lombok.Getter;
import lombok.Setter;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

@Getter
@Setter
public class MonaMAP {

    private byte[] image = new byte[0];

    private com.example.MonaServer.Mapper.PinMAP pin;

    private Long id;

    public MonaMAP(Mona mona, Group group) {
        this.image = mona.getImage();
        this.pin = new PinMAP(mona.getPin(), group);
        this.id = mona.getId();
    }

    public static List<MonaMAP> toDTOList(Map<Mona, Group> pins) {
        List<MonaMAP> list = new ArrayList<>();
        pins.forEach((a,b) -> list.add(new MonaMAP(a,b)));
        return  list;
    }

}
