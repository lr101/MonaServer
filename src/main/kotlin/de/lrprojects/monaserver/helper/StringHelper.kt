package de.lrprojects.monaserver.helper

import java.util.UUID

class StringHelper {

    companion object {
        fun listToString(ids: List<UUID>): String {
            var listOfIds = ""
            for(id in ids) {
                listOfIds += id.toString()
                listOfIds += ","
            }
            listOfIds.removeSuffix(",")
            return listOfIds
        }
    }
}