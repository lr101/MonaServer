package com.example.MonaServer.Helper;

import lombok.Getter;
import lombok.Setter;

@Setter
@Getter
public class UsernameXPoints{

    private String username;
    private int points;

    public UsernameXPoints  (String username, int points) {
        this.username = username;
        this.points = points;
    }

    public void addOnePoint() {
        points++;
    }

}
