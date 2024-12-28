package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Like
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.stereotype.Repository
import java.util.*

@Repository
interface LikeRepository : JpaRepository<Like, UUID> {

    fun findLikeByUserIdAndPinId(userId: UUID, pinId: UUID): Optional<Like>

    fun countLikeByPinIdAndLikeAllIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikeArtIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikePhotographyIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikeLocationIsTrue(pinId: UUID): Int

    @Query(
        """
        SELECT COUNT(l) FROM Like l
        WHERE l.pin.user.id = :userId AND l.likeAll = true
        """
    )
    fun countLikeByPinCreator(userId: UUID): Int

    @Query("""
        SELECT COUNT(l) FROM Like l
        WHERE l.pin.user.id = :userId AND l.likeLocation = true
        """)
    fun countLikeLocationByCreator(userId: UUID): Int

    @Query("""
        SELECT COUNT(l) FROM Like l
        WHERE l.pin.user.id = :userId AND l.likeArt = true
        """)
    fun countLikeArtByCreator(userId: UUID): Int

    @Query("""
        SELECT COUNT(l) FROM Like l
        WHERE l.pin.user.id = :userId AND l.likePhotography = true
        """)
    fun countLikePhotographyByCreator(userId: UUID): Int

}
