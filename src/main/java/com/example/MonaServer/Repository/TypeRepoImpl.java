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


    @Override
    public StickerType getStickerTypeById(Long id) {
        Optional<StickerType> m = typeRepo.findById(id);
        return m.orElse(null);
    }

    @Override
    public void deleteType(StickerType type) {
        typeRepo.delete(getStickerTypeById(type.getId()));
    }

    @Override
    public StickerType updateType(StickerType stickerType) {
        StickerType s = getStickerTypeById(stickerType.getId());
        s.setName(stickerType.getName());
        typeRepo.save(s);
        return s;
    }

}
