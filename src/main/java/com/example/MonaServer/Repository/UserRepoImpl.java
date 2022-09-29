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
    public void addPinToCreatedList(String username, Pin pin) {
        Users u = findByUsername(username);
        u.getCreatedPins().add(pin);
        userRepository.save(u);
    }

    @Override
    public void deleteUser(String username) {
        userRepository.delete(findByUsername(username));
    }

    @Override
    public Set<Pin> getMappedPins(String username) {
        Users user = this.findByUsername(username);
        return user != null ? new HashSet<>(user.getCreatedPins()) : new HashSet<>();
    }

    @Override
    public List<Object[]> getRanking() {
        return null;
    }

    @Override
    public Users findUserByPin(Pin pin) {
        Users user = null;
        for (Users u : userRepository.findAll()) {
            if(u.getCreatedPins().contains(pin)) {
                user = u;
            }
        }
        return user;
    }

}
