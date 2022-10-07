package com.example.MonaServer.DTO;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.fasterxml.jackson.annotation.JsonProperty;
import lombok.Getter;
import lombok.Setter;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.Id;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

@Getter
@Setter
public class UserDTO {

    private String username;

    public UserDTO(User user) {
        this.username = user.getUsername();
    }

    public static List<UserDTO> toDTOList(List<User> users) {
        return users.stream().map(UserDTO::new).collect(Collectors.toList());
    }

    public static Set<UserDTO> toDTOSet(Set<User> users) {
        return users.stream().map(UserDTO::new).collect(Collectors.toSet());
    }
}
