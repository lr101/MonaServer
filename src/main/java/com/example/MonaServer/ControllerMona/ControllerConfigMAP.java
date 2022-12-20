package com.example.MonaServer.ControllerMona;

import com.example.MonaServer.Controller.RestControllerGroup;
import com.example.MonaServer.Helper.UsernameXPoints;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.*;

@RestController
public class ControllerConfigMAP {
    @Autowired
    RestControllerGroup restControllerGroup;

    @GetMapping(value = "/api/ranking")
    public List<UsernameXPoints> getPointRanking () {
        List<UsernameXPoints> list = restControllerGroup.getMembers(RestControllerMonaMAP.TORNADO_GROUP_ID);
        list.remove(list.size() - 1);
        List<UsernameXPoints> list2 = restControllerGroup.getMembers(RestControllerMonaMAP.MONA_GROUP_ID);
        list2.remove(list2.size() - 1);
        for (UsernameXPoints p2 : list2) {
            if (list.stream().anyMatch(e -> e.getUsername().equals(p2.getUsername()))) {
                list.forEach(e -> {
                    if (e.getUsername().equals(p2.getUsername())) {
                        e.setPoints(e.getPoints() + p2.getPoints());
                    }
                });
            } else {
                list.add(p2);
            }
        }
        return list;
    }
}
