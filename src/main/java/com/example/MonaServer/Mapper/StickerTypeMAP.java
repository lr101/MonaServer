package com.example.MonaServer.Mapper;

import com.example.MonaServer.ControllerMona.RestControllerMonaMAP;
import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.Group;
import lombok.Getter;
import lombok.Setter;

import java.util.Objects;


@Getter
@Setter
public class StickerTypeMAP {
    private Long id;

    private String name;


    public StickerTypeMAP(GroupDTO groupDTO) {
        this.id = Objects.equals(groupDTO.getGroupId(), RestControllerMonaMAP.MONA_GROUP_ID) ? RestControllerMonaMAP.MONA_APP_ID : RestControllerMonaMAP.TORNADO_APP_ID;
        this.name = groupDTO.getName();
    }

    public StickerTypeMAP(Group group) {
        this.id = Objects.equals(group.getGroupId(), RestControllerMonaMAP.MONA_GROUP_ID) ? RestControllerMonaMAP.MONA_APP_ID : RestControllerMonaMAP.TORNADO_APP_ID;
        this.name = group.getName();
    }
}
