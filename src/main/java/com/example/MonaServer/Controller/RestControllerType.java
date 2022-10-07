package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.SecurityFilter;
import com.example.MonaServer.Repository.TypeRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
public class RestControllerType {

    @Autowired
    TypeRepo typeRepo;

    SecurityFilter securityFilter = new SecurityFilter();

    @GetMapping(value ="/api/types")
    public List<StickerType> getAllTypes() {
        return (List<StickerType>) typeRepo.findAll();
    }

    @PostMapping(value="/api/types")
    public StickerType postType(@RequestBody StickerType type) {
        securityFilter.checkAdminOnly();
        return typeRepo.save(type);
    }
}
