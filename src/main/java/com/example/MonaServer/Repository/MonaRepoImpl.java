package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Mona;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.Optional;

public class MonaRepoImpl implements MonaRepoCustom {

    @Autowired
    @Lazy
    MonaRepo monaRepository;

    public Mona findMonaById(Long id) {
        Optional<Mona> m = monaRepository.findById(id);
        return m.orElse(null);
    }

    @Override
    public Mona findMonaByPin(Pin pin) {
        for (Mona mona : monaRepository.findAll()) {
            if (mona.getPin().equals(pin)) {
                return mona;
            }
        }
        return null;
    }

    @Override
    public Mona updateMona(byte[] image, Pin pin) {
        Mona u = findMonaByPin(pin);
        u.setImage(image);
        return u;
    }

    @Override
    public void deleteMona(Mona mona) {
        monaRepository.delete(findMonaById(mona.getId()));
    }

}
