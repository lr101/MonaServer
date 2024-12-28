package de.lrprojects.monaserver.properties

object DbConstants {
    // column definitions
    const val BYTEA = "bytea"

    // tables
    const val GROUPS = "groups"
    const val PINS = "pins"
    const val USERS = "users"
    const val MEMBERS = "members"
    const val DELETE_LOG = "delete_log"

    // columns
    const val ID = "id"
    const val ADMIN_ID = "admin_id"
    const val CREATOR_ID = "creator_id"
    const val GROUP_ID = "group_id"
    const val USER_ID = "user_id"
    const val PIN_ID = "pin_id"
    const val SELECTED_BATCH = "selected_batch"
    const val STATE_PROVINCE_ID = "state_province_id"

    //fk
    const val FK_MEMBERS_USERNAME = "fk_members_username"
    const val FK_MEMBERS_GROUP_ID = "fk_members_group_id"

    //mapped by
    const val PIN = "pin"
    const val MEMBER_GROUP = "id.group"
    const val MEMBER_USER = "id.user"
    const val USER = "user"

}