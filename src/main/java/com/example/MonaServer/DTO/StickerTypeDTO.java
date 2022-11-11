package com.example.MonaServer.DTO;

import com.example.MonaServer.Entities.StickerType;
import lombok.Getter;
import lombok.Setter;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;

@Getter
@Setter
public class StickerTypeDTO {
    private Long id;
    private String name;
    private byte[] icon;
    private Long groupId;

    public StickerTypeDTO(StickerType stickerType) {
        this.id = stickerType.getId();
        this.name = stickerType.getName();
        this.icon = stickerType.getIcon();
        this.groupId = stickerType.getGroup().getId();
    }
}
