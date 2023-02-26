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
        pin = pinRepo.save(mona.getPin());
        mona.setPin(pin);
        monaRepo.saveAndFlush(mona);
        return pin;
    }

    @Override
    public Mona getMona(Long pinId) {
        Mona mona = monaRepo.getMonaFromPinId(pinId);
        if (mona == null) throw new NoSuchElementException("Mona with id: " + pinId + " cannot be found");
        return mona;
    }

    @Override
    public void updateMona(byte[] image, Long id) {
        Mona mona = getMona(id);
        mona.setImage(image);
        monaRepo.saveAndFlush(mona);
    }

}
