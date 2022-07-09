package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Versioning;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import javax.transaction.Transactional;

@Repository
@Transactional
public interface VersionRepo extends CrudRepository<Versioning, Long>, VersionRepoCustom {}