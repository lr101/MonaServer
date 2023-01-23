package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import javax.transaction.Transactional;
import java.util.*;
@Transactional
public class PinRepoImpl implements PinRepoCustom {


    @Autowired
    @Lazy
    PinRepo pinRepository;

    @Override
    @Transactional
    public Pin findByPinId(Long id) {
        Optional<Pin> p = pinRepository.findById(id);
        return p.orElseThrow();
    }

}
