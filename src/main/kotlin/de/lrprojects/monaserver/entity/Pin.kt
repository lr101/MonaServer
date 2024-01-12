package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import lombok.Getter
import lombok.Setter
import java.util.*

@Entity(name = "pins")
@Getter
@Setter
class Pin {
    @Column(name = "id", nullable = false)
    @Id
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "pins_id_generator")
    @SequenceGenerator(name = "pins_id_generator", sequenceName = "pins_id_seq", allocationSize = 1)
    private val id: Long? = null

    @Column(name = "latitude", nullable = false)
    private var latitude = 0.0

    @Column(name = "longitude", nullable = false)
    private var longitude = 0.0

    @Column(name = "creation_date", nullable = false)
    private var creationDate: Date? = null

    @OneToOne
    @JoinColumn(name = "creation_user", referencedColumnName = "username")
    private var user: User? = null

    constructor(latitude: Double, longitude: Double, creationDate: Date?, user: User?) {
        this.latitude = latitude
        this.longitude = longitude
        this.creationDate = creationDate
        this.user = user
    }

    constructor()
}