package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.UsernameXPoints;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;
import java.util.List;
import java.util.Map;
import java.util.Set;

@Repository
@Transactional
public interface GroupRepo extends CrudRepository<Group, Long>, GroupRepoCustom {

    @Query(value = "SELECT m.username, MAX(COALESCE(cup.num, 0)) as points FROM members m " +
            "    LEFT JOIN (SELECT creation_user, COUNT(*) as num FROM groups_pins gp " +
            "        JOIN pins p on gp.id = p.id " +
            " JOIN groups g on g.group_id = gp.group_id" +
            "        WHERE gp.group_id = :group " +
            "        GROUP BY p.creation_user) as cup on m.username = cup.creation_user " +
            "    GROUP BY m.username ORDER BY points DESC", nativeQuery = true)
    List<Map<String, Object>> getRankingByQuery(@Param("group") Long group);

    @Query(value = "SELECT p.* FROM groups_pins gp " +
            " JOIN pins p on p.id = gp.id " +
            " WHERE gp.group_id = 0 AND p.creation_user = 'lr'", nativeQuery = true)
    public Set<Pin> getPinsOfUserInGroup(Long id, String username);

    @Query(value = "SELECT * FROM groups g " +
            "    WHERE g.group_id IN " +
            "      (SELECT members.group_id FROM members WHERE username = :username) " +
            "  AND g.name ILIKE :search",nativeQuery = true)
    public List<Long> getGroupSearchInUserGroups(String username, String search);

    @Query(value = "SELECT * FROM groups g " +
            "    WHERE g.group_id NOT IN " +
            "      (SELECT members.group_id FROM members WHERE username = :username) " +
            "  AND g.name ILIKE :search",nativeQuery = true)
    public List<Long> getGroupSearchNotInUserGroups(String username, String search);

}