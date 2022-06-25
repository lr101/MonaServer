package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Mona;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;

@Repository
@Transactional
public interface MonaRepo extends CrudRepository<Mona, Long>, MonaRepoCustom {}