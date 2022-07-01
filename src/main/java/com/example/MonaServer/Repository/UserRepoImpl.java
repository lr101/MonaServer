package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.*;

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
    public Set<Pin> addPinToFoundList(String username, Pin pin) {
        Users u = findByUsername(username);
        u.getFoundPins().add(pin);
        userRepository.save(u);
        return u.getFoundPins();
    }

    @Override
    public Set<Pin> addPinToCreatedList(String username, Pin pin) {
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
    public Set<Pin> getMappedPins(String username) {
        Users user = this.findByUsername(username);
        Set<Pin> pins = new HashSet<>(user.getFoundPins());
        pins.addAll(user.getCreatedPins());
        return pins;
    }
}
