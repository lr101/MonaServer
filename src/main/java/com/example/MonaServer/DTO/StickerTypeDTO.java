package com.example.MonaServer.DTO;

import lombok.Getter;
import lombok.Setter;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;

@Getter
@Setter
public class StickerTypeDTO {
    private Long id;

    private String name;


    public StickerTypeDTO(Long id, String name) {
        this.id = id;
        this.name = name;
    }
}
