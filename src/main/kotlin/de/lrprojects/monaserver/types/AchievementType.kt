package de.lrprojects.monaserver.types

import jakarta.persistence.EntityManager

enum class AchievementType(val id: Int, val threshold: Int, val sqlQuery: String, val parameters: List<String>) {
    /// Have more than 100xp
    NEWBIE(0, 100,"select SUM(xp) FROM users where id = :userId", listOf("userId")),

    /// Account created before 2023 8:51:46 AM
    EARLY_ADOPTER(1,1, "select COUNT(*) FROM users WHERE creation_date < :date AND id = :userId", listOf("userId", "date")),

    /// Join the Mona group
    MONA(2, 1,"select COUNT(*) FROM members WHERE user_id = :userId AND group_id = :groupId", listOf("userId", "groupId")),

    /// Create a first pin
    CREATE_PIN(3, 1, "select COUNT(*) FROM pins WHERE creator_id = :userId", listOf("userId")),

    /// Join a first group
    JOIN_GROUP(4, 1,"select COUNT(*) FROM members WHERE user_id = :userId", listOf("userId")),

    /// Get 1000 likes in total
    LIKES_1000(5, 1000,"select COUNT(*) FROM likes WHERE user_id = :userId AND like_all = TRUE", listOf("userId")),

    /// Get 1000 art likes
    SICK_ARTIST(6, 1000,"select COUNT(*) FROM likes WHERE user_id = :userId AND like_art = TRUE", listOf("userId")),

    /// Get 1000 location likes
    TRAVELER(7, 1000,"select COUNT(*) FROM likes WHERE user_id = :userId AND like_location = TRUE", listOf("userId")),

    /// Get 1000 photography likes
    MASTER_PHOTOGRAPHER(8, 1000,"select COUNT(*) FROM likes WHERE user_id = :userId AND like_photography = TRUE", listOf("userId")),

    /// Add more than 500 pins
    YOU_ARE_AMAZING(9, 500,"select COUNT(*) FROM pins WHERE creator_id = :userId", listOf("userId"));

    fun runQuery(entityManager: EntityManager, params: Map<String, Any>): Int {
        val query = entityManager.createNativeQuery(sqlQuery, Int::class.java)
        params.forEach { (t, u) -> query.setParameter(t, u) }
        return query.singleResult as Int
    }

    fun checkClaim(entityManager: EntityManager, params: Map<String, Any>): Boolean {
        val result = runQuery(entityManager, params)
        return result >= threshold
    }

    companion object {
        fun getById(id: Int): AchievementType {
            return entries.find { it.id == id }!!
        }


    }
}