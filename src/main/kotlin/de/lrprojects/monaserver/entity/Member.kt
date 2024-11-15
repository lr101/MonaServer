package de.lrprojects.monaserver.entity

import com.fasterxml.jackson.annotation.JsonIgnore
import de.lrprojects.monaserver.helper.EmbeddedMemberKey
import de.lrprojects.monaserver.properties.DbConstants.MEMBERS
import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table
import jakarta.persistence.Temporal
import jakarta.persistence.TemporalType
import org.hibernate.annotations.CreationTimestamp
import java.time.OffsetDateTime

@Entity
@Table(name = MEMBERS)
data class Member (
    @Id
    @JsonIgnore
    var id: EmbeddedMemberKey,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var creationDate: OffsetDateTime? = null,

    @CreationTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: OffsetDateTime? = null,

    var active: Boolean = true
)
