package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import org.hibernate.annotations.CreationTimestamp
import org.hibernate.annotations.SQLDelete
import org.hibernate.annotations.SQLRestriction
import org.hibernate.annotations.UpdateTimestamp
import java.util.*

@Entity
@Table(name = "pins")
@SQLDelete(sql = "UPDATE pins SET is_deleted = true WHERE id=?")
@SQLRestriction("is_deleted=false")
open class Pin {

    @Id
    @GeneratedValue
    @Column(name = "id", nullable = false)
    open var id: UUID? = null

    @Column(name = "latitude", nullable = false)
    open var latitude = 0.0

    @Column(name = "longitude", nullable = false)
    open var longitude = 0.0

    @Column(name = "creation_date", nullable = false)
    @Temporal(TemporalType.TIMESTAMP)
    open var creationDate: Date? = null

    @UpdateTimestamp
    @Temporal(TemporalType.TIMESTAMP)
    @Column(name = "update_date")
    open var updateDate: Date? = null

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_id", referencedColumnName = "id")
    open var user: User? = null

    @Lob
    @Column(name = "image", nullable = false)
    open var image : ByteArray? = null


    @ManyToMany(mappedBy = "pins", fetch = FetchType.LAZY)
    open var groups: MutableSet<Group> = mutableSetOf()

    @Column(name = "is_deleted", nullable = false)
    open var isDeleted: Boolean = false
}