package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Versioning;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.PinRepo;
import com.example.MonaServer.Repository.VersionRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
public class RestControllerVersion {
    @Autowired
    VersionRepo versionRepo;

    @GetMapping(value = "/api/versions")
    @ResponseBody
    public List<Versioning> getVersioning(@RequestParam(required = false) Long number) {
        if (number == null) {
            return (List<Versioning>) versionRepo.findAll();
        }
        return versionRepo.getVersioning(number);
    }

    @GetMapping(value = "/api/versions/last/")
    public Long getLastVersionID () {
        return versionRepo.getLastVersionId() - 1;
    }


}
