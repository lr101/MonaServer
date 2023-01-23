package com.example.MonaServer.Repository;
import com.example.MonaServer.Entities.*;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import javax.transaction.Transactional;
import java.util.*;
@Transactional
public class MonaRepoImpl implements MonaRepoCustom {

    @Autowired
    @Lazy
    MonaRepo monaRepo;

    @Autowired
    PinRepo pinRepo;


    @Override
    public Pin createMona(byte[] image, double latitude, double longitude, User user, Date date) {
        Pin pin = new Pin(latitude, longitude, date, user);
        Mona mona = new Mona(image, pin);
        mona.setPin(pinRepo.save(mona.getPin()));
        Mona monaSaved = monaRepo.save(mona);
        return monaSaved.getPin();
    }

    @Override
    public void deleteMona(Long id){
        Mona mona = getMona(id);
        monaRepo.delete(mona);
    }

    @Override
    public Mona getMona(Long pinId) {
        Mona mona = monaRepo.getMonaFromPinId(pinId);
        if (mona == null) throw new NoSuchElementException("Mona with id: " + pinId + " cannot be found");
        return mona;
    }

    @Override
    public List<Mona> getMonasByUser(User user) {
        List<Mona> monas = new ArrayList<>();
        monaRepo.findAll().forEach(e -> {
            if (e.getPin().getUser().equals(user)) {monas.add(e);}
        });
        return  monas;
    }

    @Override
    public void updateMona(byte[] image, Long id) {
        Mona mona = getMona(id);
        mona.setImage(image);
        monaRepo.save(mona);
    }

}
