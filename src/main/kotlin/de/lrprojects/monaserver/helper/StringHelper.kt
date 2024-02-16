package de.lrprojects.monaserver.helper

class StringHelper {

    companion object {
        fun listToString(ids: List<Long>): String {
            var listOfIds = ""
            for(id in ids) {
                listOfIds += id
                listOfIds += ","
            }
            listOfIds.removeSuffix(",")
            return listOfIds
        }
    }
}