package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import java.util.*

@Entity
@Table(name = "pins")
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
    @JoinColumn(name = "creation_user", referencedColumnName = "username")
    open var user: User? = null

    @Lob
    @Column(name = "image", nullable = false)
    open var image : ByteArray? = null


    @ManyToMany(mappedBy = "pins", fetch = FetchType.LAZY)
    open var groups: MutableSet<Group> = mutableSetOf()
}