package de.lrprojects.monaserver.helper

import jakarta.persistence.Column
import jakarta.persistence.Embeddable
import java.io.Serializable
import java.util.*

@Embeddable
data class EmbeddedMemberKey(
    @Column(name = "group_id")
    val groupId: UUID,
    @Column(name = "user_id")
    val userId: UUID
): Serializable
