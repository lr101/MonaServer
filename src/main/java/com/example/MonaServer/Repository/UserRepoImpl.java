package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.ImageHelper;
import com.example.MonaServer.Helper.SecurityFilter;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import javax.imageio.ImageIO;
import javax.transaction.Transactional;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.*;
@Transactional
public class UserRepoImpl implements UserRepoCustom {

    @Autowired
    @Lazy
    UserRepo userRepo;

    @Override
    public User findByUsername(String username) {
        Optional<User> user = userRepo.findById(username);
        return user.orElseThrow();
    }

    @Override
    public void deleteUser(String username) {
        userRepo.delete(findByUsername(username));
    }

    @Override
    public void updateUser(String username, String password, String email, String token) {
        User user = findByUsername(username);
        if (password != null) {
            user.setPassword(password);
            user.setResetPasswordUrl(null);
        }
        if (email != null) user.setEmail(email);
        if (token != null) user.setToken(token);
        userRepo.save(user);
    }

    @Override
    public String setResetUrl(String username) {
        boolean flag = true;
        String random = "ERROR";
        while (flag) {
            random = SecurityFilter.generateAlphabeticRandomString(50);
            if (userRepo.getUsersWithUrl(random).size() == 0) {
                User user = userRepo.findByUsername(username);
                user.setResetPasswordUrl(random);
                userRepo.save(user);
                flag = false;
            }
        }
        return random;
    }

    @Override
    public byte[] updateProfilePicture(String username, byte[] image) {
        User user = this.findByUsername(username);
        user.setProfilePicture(ImageHelper.getProfileImage(image));
        user.setProfilePictureSmall(ImageHelper.getProfileImageSmall(image));
        userRepo.save(user);
        return user.getProfilePicture();
    }

}
