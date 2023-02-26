package com.example.MonaServer.Repository;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import javax.transaction.Transactional;
import java.util.List;
import java.util.Map;

@Repository
@Transactional
public interface PinRepo extends JpaRepository<Pin, Long>, PinRepoCustom {

    @Query(value="SELECT p.id, p.creation_user as username, p.creation_date as \"creationDate\", p.longitude, p.latitude, gp.group_id as \"groupId\"  " +
            "    FROM pins p" +
            "    JOIN groups_pins gp on p.id = gp.id" +
            "        WHERE gp.group_id IN" +
            "              (SELECT m.group_id FROM members m" +
            "                JOIN groups g on g.group_id = m.group_id" +
            "                WHERE m.username = :tokenUser OR g.visibility = 0" +
            "                GROUP BY m.group_id" +
            "              ) AND p.creation_user = :username ORDER BY p.creation_date DESC "
            , nativeQuery=true)
    List<Map<String, Object>> getPinsOfUserInGroupsOfTokenUser(@Param("username") String username, @Param("tokenUser") String tokenUser);
}