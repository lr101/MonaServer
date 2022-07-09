package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.PinRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class RestControllerMona {
    @Autowired
    MonaRepo monaRepo;

    @Autowired
    PinRepo pinRepo;

    @GetMapping(value = "/monas")
    public Mona getMonaByPinId (@RequestParam Long id) {
        return monaRepo.findMonaByPin(pinRepo.findByPinId(id));
    }

    @DeleteMapping(value = "/monas")
    public void deleteMonaByPinId (@RequestParam Long id) {
        pinRepo.deleteById(id);
    }


}
