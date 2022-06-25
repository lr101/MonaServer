package com.example.MonaServer.Helper;

import com.example.MonaServer.Entities.StickerType;
import com.example.MonaServer.Repository.TypeRepo;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Bean;
import org.springframework.stereotype.Component;
import org.springframework.stereotype.Controller;
import org.springframework.stereotype.Service;

import java.util.Scanner;

@Controller
public class ImageProcessor {


    public static StickerType getStickerType(byte[] image, TypeRepo typeRepo) {
        for(StickerType type : typeRepo.findAll()) {
            return type;
        }
        return null;
    }
}
