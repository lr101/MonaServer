package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Versioning;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import javax.transaction.Transactional;
import java.util.List;

@Repository
@Transactional
public interface VersionRepo extends CrudRepository<Versioning, Long>, VersionRepoCustom {

    @Query(value="SELECT * FROM versions WHERE date > (SELECT date FROM versions WHERE id = :id) ORDER BY date DESC", nativeQuery=true)
    List<Versioning> getVersioning(@Param("id") Long id);

    @Query(value="SELECT * FROM versions ORDER BY date DESC LIMIT 1", nativeQuery=true)
    List<Versioning> getLastVersionId();
}