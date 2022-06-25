package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Config;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Repository.PinRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.List;
import java.util.stream.Collectors;

@RestController
public class ControllerConfig {


    @GetMapping(value ="/config/")
    public Config getAllPins() {
        return new Config();
    }
}
