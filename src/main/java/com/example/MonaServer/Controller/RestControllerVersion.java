package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Versioning;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.PinRepo;
import com.example.MonaServer.Repository.VersionRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class RestControllerVersion {
    @Autowired
    VersionRepo versionRepo;

    @GetMapping(value = "/version/last")
    public Long getLastVersionID () {
        return versionRepo.getLastVersionId() - 1;
    }

    @GetMapping(value = "/version")
    public List<Versioning> getVersioningFromUsername(@RequestParam Long number) {
        return versionRepo.getVersioning(number);
    }


}
