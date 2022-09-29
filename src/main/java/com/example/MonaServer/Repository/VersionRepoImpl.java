package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Versioning;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.annotation.Lazy;
import java.util.List;


public class VersionRepoImpl implements VersionRepoCustom {


    @Autowired
    @Lazy
    VersionRepo versionRepo;


    @Override
    public Long getLastVersionId() {
        return versionRepo.count();
    }

    @Override
    public List<Versioning> getVersioning(Long number) {
        return null;
    }


    @Override
    public void addPin(Long pinId) {
        Versioning version = new Versioning(getLastVersionId(), pinId, 0);
        versionRepo.save(version);
    }

    @Override
    public void deletePin(Long pinId) {
        Versioning version = new Versioning(getLastVersionId(), pinId, 1);
        versionRepo.save(version);
    }
}
