package de.lrprojects.monaserver.entity

import jakarta.persistence.*
import lombok.Getter
import lombok.Setter
import org.hibernate.annotations.OnDelete
import org.hibernate.annotations.OnDeleteAction

@Entity(name = "monas")
@Getter
@Setter
open class Mona {

    @Lob
    @Basic(fetch=FetchType.LAZY)
    @Column(name = "image", nullable = false,  columnDefinition="BLOB")
    var image = ByteArray(0)

    @OneToOne
    @OnDelete(action = OnDeleteAction.CASCADE)
    @JoinColumn(name = "pin", nullable = false, referencedColumnName = "id")
    var pin: Pin? = null

    @Id
    @Column(name = "id", nullable = false)
    @GeneratedValue(strategy = GenerationType.SEQUENCE, generator = "mona_id_generator")
    @SequenceGenerator(name = "mona_id_generator", sequenceName = "mona_id_seq", allocationSize = 1)
    val id: Long? = null

}