package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.Mona;

import java.util.List;

public interface MonaRepoCustom {
    public Mona updateMona(byte[] image, Pin pin);
    public void deleteMona(Mona mona);
    public Mona findMonaByPin(Pin pin);
}
