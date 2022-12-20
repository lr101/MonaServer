package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Mona;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import javax.transaction.Transactional;

@Repository
@Transactional
public interface MonaRepo extends CrudRepository<Mona, Long>, MonaRepoCustom {

    @Query(value="SELECT * FROM monas WHERE pin = :id", nativeQuery=true)
    Mona getMonaFromPinId(@Param("id") Long id);

    @Query(value="SELECT group_id FROM groups_pins WHERE id = :id", nativeQuery=true)
    Long getGroupIdFromPinId(@Param("id") Long id);

}