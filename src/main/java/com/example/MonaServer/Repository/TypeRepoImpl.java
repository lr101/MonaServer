package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.StickerType;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.Optional;

public class TypeRepoImpl implements TypeRepoCustom {

    @Autowired
    @Lazy
    TypeRepo typeRepo;

    public StickerType findTypeById(Long id) {
        Optional<StickerType> m = typeRepo.findById(id);
        return m.orElse(null);
    }


    @Override
    public void deleteType(StickerType type) {
        typeRepo.delete(findTypeById(type.getId()));
    }

}
