package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table

@Entity
@Table(name = "groups_pins")
class GroupPin {
    @Id
    @Column(name = "group_id")
    val groupId: Int? = null

    @Id
    val id: Int? = null
}