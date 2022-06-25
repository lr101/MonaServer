package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

import static java.lang.Math.asin;
import static java.lang.Math.sqrt;

public class UserRepoImpl implements UserRepoCustom {

    @Autowired
    @Lazy
    UserRepo userRepository;

    @Override
    public Users findByUsername(String username) {
        ArrayList<Users> list = (ArrayList<Users>) userRepository.findAll();
        for (Users User : list) {
            if (Objects.equals(User.getUsername(), username)) {
                return User;
            }
        }
        return null;
    }

    @Override
    public Users updateUser(String username, int points) {
        Users u = findByUsername(username);
        u.setUsername(username);
        u.setPoints(u.getPoints() + points);
        userRepository.save(u);
        return u;
    }

    @Override
    public List<Pin> addPinToFoundList(String username, Pin pin) {
        Users u = findByUsername(username);
        u.getFoundPins().add(pin);
        userRepository.save(u);
        return u.getFoundPins();
    }

    @Override
    public List<Pin> addPinToCreatedList(String username, Pin pin) {
        Users u = findByUsername(username);
        u.getCreatedPins().add(pin);
        userRepository.save(u);
        return u.getCreatedPins();
    }

    @Override
    public void deleteUser(String username) {
        userRepository.delete(findByUsername(username));
    }

    @Override
    public List<Pin> getMappedPins(String username) {
        Users user = this.findByUsername(username);
        List<Pin> pins = new ArrayList<>(user.getFoundPins());
        pins.addAll(user.getCreatedPins());
        return pins;
    }
}
