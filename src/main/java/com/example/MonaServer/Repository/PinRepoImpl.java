package com.example.MonaServer.Repository;

import com.example.MonaServer.Helper.Config;
import com.example.MonaServer.Entities.Pin;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import javax.transaction.Transactional;
import java.util.*;
import java.util.stream.Collectors;

import static java.lang.Math.asin;
import static java.lang.Math.sqrt;

public class PinRepoImpl implements PinRepoCustom {


    @Autowired
    @Lazy
    PinRepo pinRepository;

    Config config = new Config();

    @Override
    @Transactional
    public Pin findByPinId(Long id) {
        Optional<Pin> p = pinRepository.findById(id);
        return p.orElse(null);
    }

    @Override
    public Pin updatePin(Pin pin) {
        Pin m = this.findByPinId(pin.getId());
        m.setLatitude(pin.getLatitude());
        m.setLongitude(pin.getLongitude());
        return m;
    }

    @Override
    public void deletePin(Long sensorPinId) {
        pinRepository.delete(this.findByPinId(sensorPinId));
    }

}
