package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Users;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;

@Repository
@Transactional
public interface UserRepo extends CrudRepository<Users, String>, UserRepoCustom {}