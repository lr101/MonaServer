package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.StickerType;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;
import java.util.Set;

@Repository
@Transactional
public interface TypeRepo extends CrudRepository<StickerType, Long>, TypeRepoCustom {

    @Query(value="SELECT * FROM types WHERE group_id = :id", nativeQuery=true)
    Set<StickerType> getTypesByGroup(@Param("id") Long groupId);

}