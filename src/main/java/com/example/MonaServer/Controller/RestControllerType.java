package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Repository.TypeRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
public class RestControllerType {

    @Autowired
    TypeRepo typeRepo;

    @GetMapping(value ="/types/")
    public List<StickerType> getAllTypes() {
        return (List<StickerType>) typeRepo.findAll();
    }

    @PostMapping(value="/types/")
    public StickerType postType(@RequestBody StickerType type) {
        return typeRepo.save(type);
    }
}
