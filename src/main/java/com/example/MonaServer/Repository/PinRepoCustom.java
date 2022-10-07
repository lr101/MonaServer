package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

public interface PinRepoCustom {
    public Pin findByPinId(Long id);
}
