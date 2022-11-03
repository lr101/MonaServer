package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Group;
import com.example.MonaServer.Entities.Mona;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;

@Repository
@Transactional
public interface GroupRepo extends CrudRepository<Group, Long>, GroupRepoCustom {

}