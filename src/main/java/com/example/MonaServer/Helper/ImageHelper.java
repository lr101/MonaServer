package com.example.MonaServer.Helper;

import org.springframework.core.io.ClassPathResource;
import org.springframework.core.io.Resource;

import javax.imageio.ImageIO;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.util.Arrays;

public class ImageHelper {

    public static final int SIZE = 500;
    public static final int SIZE_PIN = 100;
    public static final int X_OFFSET = 11;
    public static final int Y_OFFSET = 4;
    public static final int DIAMETER = 79;
    public static final int HEX_COLOR_TRANSPARENT = 0xFFFFFF;


    public static byte[] getProfileImage(byte[] image) {
        try {
            BufferedImage imageBuff = resizeImage(image, SIZE);
            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            ImageIO.write(imageBuff, "png", buffer);
            imageBuff.flush();
            return buffer.toByteArray();
        } catch (IOException | IllegalStateException e) {
            throw new IllegalStateException("image does not have the right size constrains");
        }
    }

    public static byte[] getPinImage(byte[] image) {
        try {
            //scale to SIZE_PIN x SIZE_PIN
            BufferedImage imageBuff = resizeImage(image, DIAMETER);
            //get Resources
            BufferedImage pinImage = getImageFromResources("pin_image.png");
            BufferedImage pinBorder = getImageFromResources("pin_border.png");
            //create return image
            BufferedImage returnImage = new BufferedImage(SIZE_PIN, SIZE_PIN, BufferedImage.TYPE_INT_ARGB);
            Graphics2D g = returnImage.createGraphics();
            for (int x = 0; x < SIZE_PIN; x++) {
                for (int y = 0; y < SIZE_PIN; y++) {
                    if (x >= X_OFFSET &&
                            x <= X_OFFSET + DIAMETER &&
                            y >= Y_OFFSET &&
                            y <= Y_OFFSET + DIAMETER &&
                            isNotTransparent(pinImage, x, y)) {           //draw image if pixel in pin_image.png is not transparent
                        g.setColor(new Color(imageBuff.getRGB(x - X_OFFSET,y - Y_OFFSET)));
                    } else if (isNotTransparent(pinBorder, x, y)) {   //draw image if pixel in pin_border.png is not transparent
                        g.setColor(new Color(pinBorder.getRGB(x,y)));
                    } else {                                        //default transparent
                        g.setColor(new Color(0,0,0,0));
                    }
                    g.drawLine(x,y,x,y);
                }
            }
            ByteArrayOutputStream buffer = new ByteArrayOutputStream();
            ImageIO.write(returnImage, "png", buffer);
            g.dispose();
            imageBuff.flush();
            pinImage.flush();
            pinBorder.flush();
            returnImage.flush();
            return buffer.toByteArray();
        } catch (Exception e) {
            System.out.println(e);
            throw new IllegalStateException("image does not have the right size constrains");
        }
    }

    private static boolean isNotTransparent(BufferedImage image, int x, int y ) {
        int pixel = image.getRGB(x,y);
        return (pixel >> 24) != 0x00;
    }

    private static BufferedImage resizeImage(byte[] image, int size) throws IOException {
        ByteArrayInputStream in = new ByteArrayInputStream(image);
        BufferedImage img = ImageIO.read(in);
        in.close();
        Image scaledImage = img.getScaledInstance(size, size, Image.SCALE_SMOOTH);
        BufferedImage imageBuff = new BufferedImage(size, size, BufferedImage.TYPE_INT_RGB);
        imageBuff.getGraphics().drawImage(scaledImage, 0, 0, new Color(0,0,0), null);
        scaledImage.flush();
        return imageBuff;
    }

    private static BufferedImage getImageFromResources(String name) throws IOException {
        Resource resource = new ClassPathResource("pin/" + name);
        InputStream input = resource.getInputStream();
        ByteArrayInputStream in = new ByteArrayInputStream(input.readAllBytes());
        BufferedImage img = ImageIO.read(in);
        input.close();
        in.close();
        return img;
    }
}
