package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Repository.TypeRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
public class RestControllerType {

    @Autowired
    TypeRepo typeRepo;

    @Value("${AUTH_TOKEN_ADMIN}")
    private String principalRequestValueAdmin;

    @GetMapping(value ="/api/types/")
    public List<StickerType> getAllTypes() {
        return (List<StickerType>) typeRepo.findAll();
    }

    @PostMapping(value="/api/types/")
    public StickerType postType(@RequestBody StickerType type) throws Exception {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if(!tokenUser.equals(principalRequestValueAdmin)) throw new Exception("Access denied for this token");
        return typeRepo.save(type);
    }
}
