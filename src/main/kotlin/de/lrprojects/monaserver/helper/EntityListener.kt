package de.lrprojects.monaserver.helper

import jakarta.persistence.PostRemove
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.stereotype.Component
import javax.sql.DataSource

@Component
class EntityListener {

    @Autowired
    private lateinit var dataSource: DataSource

    @PostRemove
    fun preRemove(entity: PreDeleteEntity) {
        dataSource.connection?.use { conn ->
            val stmt = conn.prepareStatement("INSERT INTO delete_log (deleted_entity_type, deleted_entity_id, creation_date) VALUES (?, ?, now())")
            stmt.setObject(1, entity.getDeletedEntityType().ordinal)
            stmt.setObject(2, entity.id)
            stmt.executeUpdate()
        }
    }
}