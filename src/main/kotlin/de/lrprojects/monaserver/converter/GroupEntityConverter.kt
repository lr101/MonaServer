package de.lrprojects.monaserver.converter

import de.lrprojects.monaserver.entity.Group
import org.openapitools.model.GroupSmall
import org.openapitools.model.Visibility
import java.time.ZoneOffset

fun Group.convertToGroupSmall() = GroupSmall(this.groupId, this.name, Visibility.fromValue(this.visibility))

fun Group.toGroupModel() = org.openapitools.model.Group(
    this.groupId,
    this.description,
    this.inviteUrl,
    this.name,
    Visibility.fromValue(this.visibility),
    this.groupAdmin?.username,
    this.link,
    this.updateDate?.toInstant()?.atOffset(ZoneOffset.UTC)
)