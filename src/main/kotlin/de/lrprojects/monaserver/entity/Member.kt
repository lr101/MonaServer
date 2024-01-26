package de.lrprojects.monaserver.entity

import jakarta.persistence.Column
import jakarta.persistence.Entity
import jakarta.persistence.Id
import jakarta.persistence.Table

@Entity
@Table(name = "members")
class Member {
    @Id
    @Column(name = "group_id")
    var groupId: Long? = null

    @Id
    var username: String? = null
}