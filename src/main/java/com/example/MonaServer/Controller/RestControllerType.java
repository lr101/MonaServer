package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Repository.TypeRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
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
    public StickerType postType(@RequestBody StickerType type, @RequestHeader Map<String, String> headers) throws Exception {
        if(headers.containsKey(Config.API_KEY_AUTH_HEADER_NAME_ADMIN) &&                                        //request header has admin API Key
                headers.get(Config.API_KEY_AUTH_HEADER_NAME_ADMIN).equals(principalRequestValueAdmin) ) {        //check if admin API key is correct
            return typeRepo.save(type);
        }
        throw new Exception("Access denied. Admin API Key not accepted");
    }
}
