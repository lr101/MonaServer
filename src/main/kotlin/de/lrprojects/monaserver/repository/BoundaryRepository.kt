package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Boundary
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.CrudRepository
import org.springframework.data.repository.query.Param
import java.time.OffsetDateTime
import java.util.*

interface BoundaryRepository : CrudRepository<Boundary, UUID> {

    @Query("""
            SELECT ST_AsGeoJSON(geom)
                FROM admin2_boundaries
            WHERE gid_2 = :gid2 
        """, nativeQuery = true)
    fun getGeoJsonFromGid(@Param("gid2") gid2: String): List<String>

    @Query("""
        SELECT p.creator_id, u.username, u.description, count(p.creator_id)::int as points, ua.achievement_id FROM pins p
            JOIN users u on p.creator_id = u.id
            LEFT JOIN user_achievement ua on u.selected_batch = ua.id
            JOIN admin2_boundaries b on p.state_province_id = b.id
        WHERE (:gid0 IS NULL OR gid_0 = :gid0) 
            AND (:gid1 IS NULL OR gid_1 = :gid1)
            AND (:gid2 IS NULL OR gid_2 = :gid2)
            AND (CAST(:since AS timestamp with time zone) IS NULL OR p.creation_date > CAST(:since AS timestamp with time zone))
        GROUP BY p.creator_id, u.username, u.description, ua.achievement_id ORDER BY points DESC, u.username""", nativeQuery = true)
    fun getUserRanking(
        @Param("gid0") gid0: String?,
        @Param("gid1") gid1: String?,
        @Param("gid2") gid2: String?,
        @Param("since") since: OffsetDateTime?,
        pageable: Pageable
    ) : List<Array<Any>>

    @Query("""
        SELECT p.group_id, g.name, g.visibility, g.description, count(p.group_id)::int as points FROM pins p
            JOIN groups g on p.group_id = g.id
            JOIN admin2_boundaries b on p.state_province_id = b.id
        WHERE (:gid0 IS NULL OR gid_0 = :gid0) 
            AND (:gid1 IS NULL OR gid_1 = :gid1)
            AND (:gid2 IS NULL OR gid_2 = :gid2)
            AND (CAST(:since AS timestamp with time zone) IS NULL OR p.creation_date > CAST(:since AS timestamp with time zone))
        GROUP BY p.group_id, g.name, g.visibility, g.description ORDER BY points DESC, g.name""", nativeQuery = true)
    fun getGroupRanking(
        @Param("gid0") gid0: String?,
        @Param("gid1") gid1: String?,
        @Param("gid2") gid2: String?,
        @Param("since") since: OffsetDateTime?,
        pageable: Pageable
    ) : List<Array<Any>>


    @Query("""
    SELECT * FROM admin2_boundaries
    WHERE ST_Contains(
        admin2_boundaries.geom,
        ST_SetSRID(ST_Point(:longitude, :latitude), 4326)
    )
    OR id = (
        SELECT a.id 
        FROM admin2_boundaries a
        ORDER BY 
            ST_Distance(
                a.geom,
                ST_SetSRID(ST_Point(:longitude, :latitude), 4326)
            )
        LIMIT 1
    )
    LIMIT 1
""", nativeQuery = true)
    fun getBoundaryOrClosest(@Param("latitude") latitude: Double, @Param("longitude") longitude: Double): Boundary?


    @Query(
        """
    SELECT 0 AS level, gid_0 AS gid, name_0 AS name FROM admin2_boundaries WHERE name_0 ILIKE CONCAT('%', :searchTerm, '%') GROUP BY gid_0, name_0
    UNION ALL
    SELECT 1 AS level, gid_1 AS gid, name_1 AS name FROM admin2_boundaries WHERE name_1 ILIKE CONCAT('%', :searchTerm, '%') GROUP BY gid_1, name_1
    UNION ALL
    SELECT 2 AS level, gid_2 AS gid, name_2 AS name FROM admin2_boundaries WHERE name_2 ILIKE CONCAT('%', :searchTerm, '%')
    """, nativeQuery = true)
    fun searchBoundaries(searchTerm: String?, pageable: Pageable): List<Array<Any>>

}