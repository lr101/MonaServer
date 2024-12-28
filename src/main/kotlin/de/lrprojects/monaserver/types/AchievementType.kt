package de.lrprojects.monaserver.types

import jakarta.persistence.EntityManager

enum class AchievementType(val id: Int, val threshold: Int, private val sqlQuery: String, val parameters: List<String>, val thresholdUp : Boolean = true, ) {
    /// Have more than 10 pins in one admin2 boundary
    LOCAL_CONTRIBUTOR(0, 10,"select COUNT(*) as points FROM pins WHERE creator_id = :userId GROUP BY state_province_id ORDER BY points DESC  LIMIT 1", listOf("userId")),

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
    YOU_ARE_AMAZING(9, 500,"select COUNT(*) FROM pins WHERE creator_id = :userId", listOf("userId")),

    REGIONAL_MASTER(10, 100,"select COUNT(*) as points FROM pins JOIN admin2_boundaries ON pins.state_province_id = admin2_boundaries.id WHERE creator_id = :userId GROUP BY admin2_boundaries.gid_1 ORDER BY points DESC LIMIT 1", listOf("userId")),

    COUNTRY_MASTER(11, 250,"select COUNT(*) as points FROM pins JOIN admin2_boundaries ON pins.state_province_id = admin2_boundaries.id WHERE creator_id = :userId GROUP BY admin2_boundaries.gid_0 ORDER BY points DESC LIMIT 1", listOf("userId")),

    LOCAL_HERO(12, 3,"""
       WITH user_points AS (
        SELECT
            creator_id,
            admin2_boundaries.gid_2,
            RANK() OVER (PARTITION BY admin2_boundaries.gid_2 ORDER BY COUNT(*) DESC) AS rank
        FROM
            pins
                JOIN
            admin2_boundaries ON pins.state_province_id = admin2_boundaries.id
        GROUP BY
            creator_id, admin2_boundaries.gid_2
    )
    SELECT rank FROM user_points WHERE creator_id = :userId ORDER BY rank LIMIT 1;
    """, listOf("userId"), false),

    REGIONAL_HERO(13, 3,"""
        WITH user_points AS (
        SELECT
            creator_id,
            admin2_boundaries.gid_1,
            RANK() OVER (PARTITION BY admin2_boundaries.gid_1 ORDER BY COUNT(*) DESC) AS rank
        FROM
            pins
                JOIN
            admin2_boundaries ON pins.state_province_id = admin2_boundaries.id
        GROUP BY
            creator_id, admin2_boundaries.gid_1
    )
    SELECT rank FROM user_points WHERE creator_id = :userId ORDER BY rank LIMIT 1;
    """, listOf("userId"), false),

    COUNTRY_HERO(14, 3,"""
       WITH user_points AS (
        SELECT
            creator_id,
            admin2_boundaries.gid_0,
            RANK() OVER (PARTITION BY admin2_boundaries.gid_0 ORDER BY COUNT(*) DESC) AS rank
        FROM
            pins
                JOIN
            admin2_boundaries ON pins.state_province_id = admin2_boundaries.id
        GROUP BY
            creator_id, admin2_boundaries.gid_0
    )
    SELECT rank FROM user_points WHERE creator_id = :userId ORDER BY rank LIMIT 1;
    """, listOf("userId"), false),

    WORLD_HERO(15, 3,"""
        WITH user_points AS (
            SELECT
                creator_id,
                RANK() OVER ( ORDER BY COUNT(*) DESC ) as rank
            FROM pins
            GROUP BY creator_id
        )
        SELECT rank FROM user_points WHERE creator_id = :userId;
    """, listOf("userId"), false);

    fun runQuery(entityManager: EntityManager, params: Map<String, Any>): Int {
        val query = entityManager.createNativeQuery(sqlQuery, Int::class.java)
        params.forEach { (t, u) -> query.setParameter(t, u) }
        return query.singleResult as Int
    }

    fun checkClaim(entityManager: EntityManager, params: Map<String, Any>): Boolean {
        val result = runQuery(entityManager, params)
        return if (thresholdUp) result >= threshold else result <= threshold
    }

    companion object {
        fun getById(id: Int): AchievementType {
            return entries.find { it.id == id }!!
        }


    }
}