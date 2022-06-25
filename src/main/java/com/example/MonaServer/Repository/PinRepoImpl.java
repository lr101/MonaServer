package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Config;
import com.example.MonaServer.Entities.Pin;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.stream.Collectors;

import static java.lang.Math.asin;
import static java.lang.Math.sqrt;

public class PinRepoImpl implements PinRepoCustom {


    @Autowired
    @Lazy
    PinRepo pinRepository;

    Config config = new Config();

    @Override
    public Pin findByPinId(Long id) {
        ArrayList<Pin> list = (ArrayList<Pin>) pinRepository.findAll();
        for (Pin Pin : list) {
            if (Objects.equals(Pin.getId(), id)) {
                return Pin;
            }
        }
        return null;
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


    @Override
    public List<Pin> findOtherPinsInRadius(double latitude, double longitude, List<Pin> userPins) {
        return  ((List<Pin>) pinRepository.findAll()).stream().filter(p -> !filterOutsideOfRadius(latitude, longitude, p, userPins)).collect(Collectors.toList());
    }

    private boolean filterOutsideOfRadius(double lat1,double lon1, Pin pin, List<Pin> userPins){
        return userPins.contains(pin) || (calcDistance(lat1, lon1, pin.getLatitude(), pin.getLongitude()) > config.radius);
    }

    public static double calcDistance(double lat1,double lon1,double lat2,double lon2) {
        double p = 0.017453292519943295;
        double a = 0.5 - Math.cos((lat2 - lat1) * p)/2 +
                Math.cos(lat1 * p) * Math.cos(lat2 * p) *
                        (1 - Math.cos((lon2 - lon1) * p))/2;
        return 12742 * asin(sqrt(a)) * 1000;
    }
}
