package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;
import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Helper.UsernameXPoints;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.UserRepo;
import org.imgscalr.Scalr;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.*;
import java.util.stream.Collectors;

@RestController
public class ControllerConfig {

    @Autowired
    MonaRepo monaRepo;

    @Autowired
    UserRepo userRepo;

    @Value("${AUTH_TOKEN_ADMIN}")
    private String principalRequestValueAdmin;

    @GetMapping(value = "/api/ranking")
    public List<UsernameXPoints> getPointRanking () {
        List<UsernameXPoints> list = new ArrayList<>();
        userRepo.getRanking().forEach(e -> list.add(new UsernameXPoints((String) e[0], ((java.math.BigInteger) e[1]).longValue())));
        return list;
    }

    @GetMapping(value = "/api/compress")
    public void compressAllMonas(@RequestHeader Map<String, String> headers) throws Exception {
        String tokenUser = (String) SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if(!tokenUser.equals(principalRequestValueAdmin)) throw new Exception("Access denied for this token");
        List<Mona> monas = (List<Mona>) monaRepo.findAll();
        int i = 0;
        for (Mona mona : monas) {
            i++;
            int before = mona.getImage().length / 1000;
            monaRepo.updateMona(compress(mona.getImage()), mona.getPin());
            System.out.println(i + " " + before + "kB -> " + mona.getImage().length / 1000 + "kB");
        }
    }

    private byte[] compress(byte[] imageArray) {
        try {
            InputStream is = new ByteArrayInputStream(imageArray);
            BufferedImage image = ImageIO.read(is);

            File compressedImageFile = new File("D:\\lukas\\Documents\\GIT\\Lukas - Git\\MonaServer\\DB_Backup\\compress.jpg");
            OutputStream os = new FileOutputStream(compressedImageFile);

            Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName("jpg");
            ImageWriter writer = (ImageWriter) writers.next();

            ImageOutputStream ios = ImageIO.createImageOutputStream(os);
            writer.setOutput(ios);

            ImageWriteParam param = writer.getDefaultWriteParam();

            param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);

            if (imageArray.length > 200000) {
                param.setCompressionQuality(0.1f);
            } else {
                param.setCompressionQuality(0.7f);
            }

            writer.write(null, new IIOImage(image, null, null), param);

            os.close();
            ios.close();
            writer.dispose();
            return Files.readAllBytes(rotateImage(compressedImageFile, Scalr.Rotation.CW_90));
        } catch (Exception e) {
            return null;
        }
    }

    public static Path rotateImage(File originalImageFile, Scalr.Rotation rotation) {
        try {
            BufferedImage originalImage = ImageIO.read(originalImageFile);
            BufferedImage resizedImage = Scalr.rotate(originalImage, rotation);

            File resizedFile = new File("D:\\lukas\\Documents\\GIT\\Lukas - Git\\MonaServer\\DB_Backup\\compressRotated.jpg");
            ImageIO.write(resizedImage, "jpg", resizedFile);

            originalImage.flush();
            resizedImage.flush();
            return resizedFile.toPath();
        } catch (IOException e) {
            e.printStackTrace();
        }
        return null;
    }
}
