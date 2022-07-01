package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.UserPassword;
import com.example.MonaServer.Entities.Users;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;

@Repository
@Transactional
public interface UserPswRepo extends CrudRepository<UserPassword, String>, UserPswRepoCustom {}