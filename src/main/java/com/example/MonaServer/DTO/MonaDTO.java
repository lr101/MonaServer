package com.example.MonaServer.DTO;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.OnDelete;
import org.hibernate.annotations.OnDeleteAction;
import org.springframework.context.annotation.Lazy;

import javax.persistence.*;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Getter
@Setter
public class MonaDTO {

    private byte[] image = new byte[0];

    private PinDTO pin;

    private Long id;

    public MonaDTO(Mona mona) {
        this.image = mona.getImage();
        this.pin = new PinDTO(mona.getPin());
        this.id = mona.getId();
    }

    public static List<MonaDTO> toDTOList(List<Mona> Monas) {
        return Monas.stream().map(MonaDTO::new).collect(Collectors.toList());
    }

    public static Set<MonaDTO> toDTOSet(Set<Mona> Monas) {
        return Monas.stream().map(MonaDTO::new).collect(Collectors.toSet());
    }

}
