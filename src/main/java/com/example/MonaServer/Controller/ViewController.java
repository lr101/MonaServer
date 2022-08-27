package com.example.MonaServer.Controller;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.GetMapping;


@Controller
public class ViewController {

    @GetMapping("/privacy-policy")
    public String index() {
        return "privacy-policy";
    }

    @GetMapping("/agb")
    public String agb() {
        return "agb";
    }


}
