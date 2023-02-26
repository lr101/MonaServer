package com.example.MonaServer.Repository;

import com.example.MonaServer.DTO.GroupDTO;
import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import com.example.MonaServer.Helper.UsernameXPoints;
import org.springframework.data.jpa.repository.JpaRepository;
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
public interface GroupRepo extends JpaRepository<Group, Long>, GroupRepoCustom {

    @Query(value = "SELECT username, count(creation_user) as points FROM members m" +
            "    LEFT JOIN (SELECT pins.id, creation_user FROM pins JOIN public.groups_pins gp on pins.id = gp.id" +
            "               WHERE gp.group_id = :group) as pg on pg.creation_user = m.username" +
            "    WHERE group_id = :group " +
            "GROUP BY username ORDER BY points DESC, username", nativeQuery = true)
    List<Map<String, Object>> getRankingByQuery(@Param("group") Long group);

    @Query(value = "SELECT p.* FROM groups_pins gp " +
            " JOIN pins p on p.id = gp.id " +
            " WHERE gp.group_id = 0 AND p.creation_user = 'lr'", nativeQuery = true)
    public List<Map<String, Object>> getPinsOfUserInGroup(Long id, String username);

    @Query(value = "SELECT g.group_id FROM groups g " +
            "    WHERE g.group_id IN " +
            "      (SELECT members.group_id FROM members WHERE username = :username) " +
            "  AND g.name ILIKE :search",nativeQuery = true)
    public List<Long> getGroupSearchInUserGroups(String username, String search);

    @Query(value = "SELECT g.group_id FROM groups g " +
            "    WHERE g.group_id NOT IN " +
            "      (SELECT members.group_id FROM members WHERE username = :username) " +
            "  AND g.name ILIKE :search",nativeQuery = true)
    public List<Long> getGroupSearchNotInUserGroups(String username, String search);

}