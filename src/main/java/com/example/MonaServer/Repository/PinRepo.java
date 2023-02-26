package com.example.MonaServer.Repository;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import javax.transaction.Transactional;
import java.util.List;
import java.util.Map;

@Repository
@Transactional
public interface PinRepo extends CrudRepository<Pin, Long>, PinRepoCustom {

    @Query(value="SELECT p.id, p.creation_user, p.creation_date, p.longitude, p.latitude, gp.group_id " +
            "FROM pins p " +
            "JOIN groups_pins gp on p.id = gp.id " +
            "JOIN members m on gp.group_id = m.group_id " +
            "JOIN groups g on gp.group_id = g.group_id " +
            "WHERE p.creation_user = :username AND (m.username = :tokenUser OR g.visibility = 0)"
            , nativeQuery=true)
    List<Map<String, Object>> getPinsOfUserInGroupsOfTokenUser(@Param("username") String username, @Param("tokenUser") String tokenUser);
}