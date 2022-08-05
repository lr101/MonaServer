package com.example.MonaServer.Controller;

import com.example.MonaServer.Helper.Config;
import org.springframework.web.bind.annotation.*;

@RestController
public class ControllerConfig {


    @GetMapping(value ="/config/")
    public Config getAllPins() {
        return new Config();
    }
}
