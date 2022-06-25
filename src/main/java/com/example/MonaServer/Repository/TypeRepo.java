package com.example.MonaServer.Repository;

import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.StickerType;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;

import javax.transaction.Transactional;

@Repository
@Transactional
public interface TypeRepo extends CrudRepository<StickerType, Long>, TypeRepoCustom {}