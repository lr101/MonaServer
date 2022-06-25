package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;

import java.util.ArrayList;
import java.util.List;

public interface PinRepoCustom {
    public Pin findByPinId(Long id);
    public Pin updatePin(Pin pin);
    public void deletePin (Long id);
    public List<Pin> findOtherPinsInRadius(double latitude, double longitude, List<Pin> userPins);
}
