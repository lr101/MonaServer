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

    @Query(value = "SELECT COUNT(*) FROM pins WHERE creation_user = :username",nativeQuery = true)
    public Long getUserPoints(String username);

    @Query(value = "SELECT * FROM users WHERE reset_password_url = :url",nativeQuery = true)
    public List<User> getUsersWithUrl(String url);
}