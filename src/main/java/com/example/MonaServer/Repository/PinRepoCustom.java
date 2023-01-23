package com.example.MonaServer.Repository;


import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;

import javax.transaction.Transactional;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
@Transactional
public interface PinRepoCustom {
    public Pin findByPinId(Long id);
}
