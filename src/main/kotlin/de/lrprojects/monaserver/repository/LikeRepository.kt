package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Like
import org.springframework.data.repository.CrudRepository
import org.springframework.stereotype.Repository
import java.util.*

@Repository
interface LikeRepository : CrudRepository<Like, UUID> {

    fun countLikeByPinId(pinId: UUID): Long

    fun findLikeByUserIdAndPinId(userId: UUID, pinId: UUID): Optional<Like>

    fun countLikeByPinIdAndLikeIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikeArtIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikePhotographyIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikeLocationIsTrue(pinId: UUID): Int

}
