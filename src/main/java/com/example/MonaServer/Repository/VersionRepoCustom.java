package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Versioning;

import java.util.List;

public interface VersionRepoCustom {
    public Long getLastVersionId();

    public List<Versioning> getVersioning(Long number);

    public void addPin(Long pinId);

    public void deletePin(Long pinId);
}
