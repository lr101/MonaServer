package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Versioning;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;

import java.util.Date;
import java.util.List;


public class VersionRepoImpl implements VersionRepoCustom {


    @Autowired
    @Lazy
    VersionRepo versionRepo;


    @Override
    public List<Versioning> getLastVersionId() {
        return null;
    }

    @Override
    public List<Versioning> getVersioning(Long number) {
        return null;
    }


    @Override
    public Long addPin(Long pinId, Date date) {
        Versioning version = new Versioning(pinId, 0, date);
        return versionRepo.save(version).getId();
    }

    @Override
    public Long deletePin(Long pinId, Date date) {
        Versioning version = new Versioning(pinId, 1, date);
        return versionRepo.save(version).getId();
    }
}
