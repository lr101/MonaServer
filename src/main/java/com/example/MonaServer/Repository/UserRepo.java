package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Pin;
import com.example.MonaServer.Entities.User;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;
import java.util.List;
import java.util.Set;

@Repository
@Transactional
public interface UserRepo extends CrudRepository<User, String>, UserRepoCustom {
    @Query(value = "SELECT a.username, COUNT(u.creation_user) as points FROM pins u RIGHT JOIN users a on a.username = u.creation_user GROUP BY a.username ORDER BY points DESC",nativeQuery = true)
    public List<Object[]> getRanking();

    @Query(value = "SELECT COUNT(*) FROM pins WHERE creation_user = :username",nativeQuery = true)
    public Long getUserPoints(String username);
}