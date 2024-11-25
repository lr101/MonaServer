package de.lrprojects.monaserver.repository

import de.lrprojects.monaserver.entity.Like
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository
import java.util.*

@Repository
interface LikeRepository : JpaRepository<Like, UUID> {

    fun countLikeByPinId(pinId: UUID): Long

    fun findLikeByUserIdAndPinId(userId: UUID, pinId: UUID): Optional<Like>

    fun countLikeByPinIdAndLikeIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikeArtIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikePhotographyIsTrue(pinId: UUID): Int

    fun countLikeByPinIdAndLikeLocationIsTrue(pinId: UUID): Int

    fun countLikeByUserIdAndLikeIsTrue(userId: UUID): Int

    fun countLikeByUserIdAndLikeLocationIsTrue(userId: UUID): Int

    fun countLikeByUserIdAndLikeArtIsTrue(userId: UUID): Int

    fun countLikeByUserIdAndLikePhotographyIsTrue(userId: UUID): Int

}
