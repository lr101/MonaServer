package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.GeneratedValue
import jakarta.persistence.Id
import jakarta.persistence.Table
import java.util.*

@Entity
@Table(name = "admin2_boundaries")
data class Boundary (

    @Id
    @GeneratedValue(generator = "UUID")
    val id: UUID? = null,

    @Column(name = "gid_0", nullable = true)
    val gid0: String? = null,

    @Column(name = "name_0", nullable = true)
    val name0: String? = null,

    @Column(name = "gid_1", nullable = true)
    val gid1: String? = null,

    @Column(name = "name_1", nullable = true)
    val name1: String? = null,

    @Column(name = "gid_2", nullable = true)
    val gid2: String? = null,

    @Column(name = "name_2", nullable = true)
    val name2: String? = null,

)