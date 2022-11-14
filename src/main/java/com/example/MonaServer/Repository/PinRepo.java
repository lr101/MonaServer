package com.example.MonaServer.Repository;
import com.example.MonaServer.Entities.Mona;
import com.example.MonaServer.Entities.Pin;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.stereotype.Repository;
import javax.transaction.Transactional;
import java.util.List;

@Repository
@Transactional
public interface PinRepo extends CrudRepository<Pin, Long>, PinRepoCustom {}