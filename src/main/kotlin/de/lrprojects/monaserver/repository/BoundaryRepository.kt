package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Boundary
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.CrudRepository
import org.springframework.data.repository.query.Param
import java.util.*

interface BoundaryRepository : CrudRepository<Boundary, UUID> {

    @Query("""
            SELECT ST_AsGeoJSON(geom)
                FROM admin2_boundaries
            WHERE gid_0 = :gid0 
        """, nativeQuery = true)
    fun getGeoJsonFromGid(@Param("gid0") gid0: String): List<String>

    @Query("""
        SELECT p.creator_id, u.username, u.description, count(p.creator_id)::int as points, ua.achievement_id FROM pins p
            JOIN users u on p.creator_id = u.id
            LEFT JOIN user_achievement ua on u.selected_batch = ua.id
            JOIN admin2_boundaries b on p.state_province_id = b.id
        WHERE :gid0 IS NULL OR gid_0 = :gid0 
            AND :gid1 IS NULL OR gid_1 = :gid1
            AND :gid2 IS NULL OR gid_2 = :gid2 
        GROUP BY p.creator_id, u.username, u.description, ua.achievement_id ORDER BY points DESC, u.username""", nativeQuery = true)
    fun getUserRanking(
        @Param("gid0") gid0: String?,
        @Param("gid1") gid1: String?,
        @Param("gid2") gid2: String?,
        pageable: Pageable
    ) : List<Array<Any>>

    @Query("""
        SELECT p.group_id, g.name, g.visibility, count(p.group_id)::int as points FROM pins p
            JOIN groups g on p.group_id = g.id
            JOIN admin2_boundaries b on p.state_province_id = b.id
        WHERE :gid0 IS NULL OR gid_0 = :gid0 
            AND :gid1 IS NULL OR gid_1 = :gid1
            AND :gid2 IS NULL OR gid_2 = :gid2 
        GROUP BY p.group_id, g.name, g.visibility ORDER BY points DESC, g.name""", nativeQuery = true)
    fun getGroupRanking(
        @Param("gid0") gid0: String?,
        @Param("gid1") gid1: String?,
        @Param("gid2") gid2: String?,
        pageable: Pageable
    ) : List<Array<Any>>


    @Query("""
        SELECT * FROM admin2_boundaries
        WHERE ST_Contains(
            admin2_boundaries.geom,
            ST_SetSRID(ST_Point(:longitude, :latitude), 4326))
    """, nativeQuery = true)
    fun getBoundaryByLatLong(@Param("latitude") latitude: Double, @Param("longitude") longitude: Double): Boundary?

}