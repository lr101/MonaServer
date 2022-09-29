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

    @Query(value="SELECT * FROM versions WHERE id > :id ORDER BY id", nativeQuery=true)
    List<Versioning> getVersioning(@Param("id") Long id);
}