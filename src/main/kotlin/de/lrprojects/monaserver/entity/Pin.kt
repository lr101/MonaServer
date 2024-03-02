package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import org.hibernate.annotations.SQLDelete
import org.hibernate.annotations.SQLRestriction
import java.util.*

@Entity
@Table(name = "pins")
@SQLDelete(sql = "UPDATE pins SET is_deleted = true WHERE id=?")
@SQLRestriction("is_deleted=false")
open class Pin {
    @Column(name = "id", nullable = false)
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "pins_id_generator")
    @SequenceGenerator(name = "pins_id_generator", sequenceName = "pins_id_seq", allocationSize = 1)
    open var id: Long? = null

    @Column(name = "latitude", nullable = false)
    open var latitude = 0.0

    @Column(name = "longitude", nullable = false)
    open var longitude = 0.0

    @Column(name = "creation_date", nullable = false)
    open var creationDate: Date? = null

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "creator_id", referencedColumnName = "user_id")
    open var user: User? = null

    @Lob
    @Column(name = "image", nullable = false)
    open var image : ByteArray? = null


    @ManyToMany(mappedBy = "pins", fetch = FetchType.LAZY)
    open var groups: MutableSet<Group> = mutableSetOf()

    @Column(name = "is_deleted", nullable = false)
    open var isDeleted: Boolean = false
}