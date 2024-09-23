package de.lrprojects.monaserver.entity

import de.lrprojects.monaserver.config.DbConstants.BYTEA
import de.lrprojects.monaserver.config.DbConstants.CREATOR_ID
import de.lrprojects.monaserver.config.DbConstants.GROUP_ID
import de.lrprojects.monaserver.config.DbConstants.ID
import de.lrprojects.monaserver.config.DbConstants.PINS
import de.lrprojects.monaserver.helper.DeletedEntityType
import de.lrprojects.monaserver.helper.PreDeleteEntity
import jakarta.persistence.*
import org.hibernate.annotations.UpdateTimestamp
import java.util.*
import javax.sql.DataSource

@Entity
@Table(name = PINS)
class Pin (

    @Column(nullable = false)
    var latitude: Double = 0.0,

    @Column(nullable = false)
    var longitude: Double = 0.0,

    @Column(nullable = false)
    @Temporal(TemporalType.TIMESTAMP)
    var creationDate: Date? = null,

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column
    var updateDate: Date? = null,

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = CREATOR_ID, referencedColumnName = ID, nullable = false)
    var user: User? = null,

    @Column(nullable = false, columnDefinition = BYTEA)
    @Basic(fetch = FetchType.LAZY)
    var pinImage : ByteArray? = null,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = GROUP_ID)
    var group: Group? = null,

    @Column(nullable = false)
    var isDeleted: Boolean = false,

    @Transient
    private var dataSource: DataSource? = null
): PreDeleteEntity() {
    override fun getDeletedEntityType() = DeletedEntityType.PIN
}