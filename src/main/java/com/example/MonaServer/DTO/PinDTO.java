package com.example.MonaServer.DTO;

import com.example.MonaServer.Entities.Pin;
import lombok.Getter;
import lombok.Setter;
import java.util.Date;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Getter
@Setter
public class PinDTO {

    private Long id;

    private double latitude;

    private double longitude;

    private Date creationDate;

    private String username;

    public PinDTO(Pin pin) {
        this.id =  pin.getId();
        this.latitude = pin.getLatitude();
        this.longitude = pin.getLongitude();
        this.creationDate = pin.getCreationDate();
        this.username = (pin.getUser() == null) ? null : pin.getUser().getUsername();
    }

    public static List<PinDTO> toDTOList(List<Pin> pins) {
        return pins.stream().map(PinDTO::new).collect(Collectors.toList());
    }

    public static Set<PinDTO> toDTOSet(Set<Pin> pins) {
        return pins.stream().map(PinDTO::new).collect(Collectors.toSet());
    }


}
