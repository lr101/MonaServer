package com.example.MonaServer.Controller;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Repository.MonaRepo;
import com.example.MonaServer.Repository.PinRepo;
import com.example.MonaServer.Repository.VersionRepo;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.ObjectReader;
import com.fasterxml.jackson.databind.node.ObjectNode;
import org.imgscalr.Scalr;
import org.springframework.beans.factory.annotation.Autowired;
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
import java.util.Iterator;
import java.util.List;

@RestController
public class RestControllerMona {
    @Autowired
    MonaRepo monaRepo;

    @Autowired
    PinRepo pinRepo;

    @Autowired
    VersionRepo versionRepo;


    @GetMapping(value = "/mona/all")
    public List<Mona> getMonas () {
        return (List<Mona>) monaRepo.findAll();
    }

    @GetMapping(value = "/monas")
    public Mona getMonaByPinId (@RequestParam Long id) {
        Mona mona = monaRepo.findMonaByPin(pinRepo.findByPinId(id));
        return mona;
    }

    @GetMapping(value = "/compress")
    public void compressAllMonas() {
        List<Mona> monas = (List<Mona>) monaRepo.findAll();
        int i = 0;
        for (Mona mona : monas) {
            i++;
            int before = mona.getImage().length / 1000;
            monaRepo.updateMona(compress(mona.getImage()), mona.getPin());
            System.out.println(i + " " + before + "kB -> " + mona.getImage().length / 1000 + "kB");
        }
    }

    @PutMapping(value = "/monas/{pin}/")
    public void addExistingPinToUser(@PathVariable("pin") Long id, @RequestBody ObjectNode json) throws IOException {
        ObjectMapper mapper = new ObjectMapper();
        ObjectReader reader = mapper.readerFor(new TypeReference<byte[]>() {});
        byte[] image = reader.readValue(json.get("image"));
        Pin pin = pinRepo.findByPinId(id);
        if (pin != null) {
            monaRepo.updateMona(image, pin);
            return;
        }
        throw new IllegalArgumentException("Picture could not be updated");
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

    @DeleteMapping(value = "/monas")
    public void deleteMonaByPinId (@RequestParam Long id) {
        pinRepo.deleteById(id);
        versionRepo.deletePin(id);
    }


}
