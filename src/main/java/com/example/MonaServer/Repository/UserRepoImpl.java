package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Users;
import com.example.MonaServer.Helper.UsernameXPoints;
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
        u.setPoints(points);
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
        u.addPoints(1);
        System.out.println(u.getUsername() + " " +  u.getPoints());
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

    @Override
    public List<UsernameXPoints> getRanking() {
        List<UsernameXPoints> list = new ArrayList<>();
        userRepository.findAll().forEach(e -> list.add(new UsernameXPoints(e.getUsername(), e.getPoints())));
        list.sort(Comparator.comparingInt(UsernameXPoints::points));
        Collections.reverse(list);
        return list;
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
