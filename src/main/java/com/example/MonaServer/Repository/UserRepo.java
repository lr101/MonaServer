package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Users;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;
import java.util.List;
import java.util.Map;

@Repository
@Transactional
public interface UserRepo extends CrudRepository<Users, String>, UserRepoCustom {
    @Query(value = "SELECT a.username, COUNT(u.username) as points FROM created_pins u RIGHT JOIN users a on a.username = u.username GROUP BY a.username ORDER BY points DESC",nativeQuery = true)
    public List<Object[]> getRanking();
}