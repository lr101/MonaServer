package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;
import java.util.List;

@Repository
@Transactional
public interface GroupRepo extends CrudRepository<Group, Long>, GroupRepoCustom {
    @Query(value = "SELECT group_id FROM groups_pins WHERE id= :pinId", nativeQuery = true)
    public List<Long> getGroupIdFromPinId(Long pinId);
}