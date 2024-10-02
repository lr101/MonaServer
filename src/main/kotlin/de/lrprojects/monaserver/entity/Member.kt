package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.config.DbConstants.MEMBERS
import de.lrprojects.monaserver.helper.EmbeddedMemberKey
import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import java.time.OffsetDateTime

@Entity
@Table(name = MEMBERS)
data class Member (
    @Id
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
