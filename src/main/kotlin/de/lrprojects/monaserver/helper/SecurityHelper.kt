package de.lrprojects.monaserver.helper

import java.util.*

object SecurityHelper {
    fun generateAlphabeticRandomString(targetStringLength: Int): String {
        val leftLimit = 97 // letter 'a'
        val rightLimit = 122 // letter 'z'
        val random = Random()
        return random.ints(leftLimit, rightLimit + 1)
            .limit(targetStringLength.toLong())
            .collect(
                { StringBuilder() },
                { obj: StringBuilder, codePoint: Int -> obj.appendCodePoint(codePoint) }) { obj: StringBuilder, s: StringBuilder? ->
                obj.append(
                    s
                )
            }
            .toString()
    }
}