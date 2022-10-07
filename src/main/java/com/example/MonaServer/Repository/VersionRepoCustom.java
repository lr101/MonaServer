package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Versioning;

import java.util.Date;
import java.util.List;

public interface VersionRepoCustom {
    public List<Versioning> getLastVersionId();

    public List<Versioning> getVersioning(Long number);

    public Long addPin(Long pinId, Date date);

    public Long deletePin(Long pinId, Date date);
}
