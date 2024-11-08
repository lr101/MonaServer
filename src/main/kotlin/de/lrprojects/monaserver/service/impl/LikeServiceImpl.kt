package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toEntity
import de.lrprojects.monaserver.repository.LikeRepository
import de.lrprojects.monaserver.service.api.LikeService
import de.lrprojects.monaserver_api.model.CreateLikeDto
import de.lrprojects.monaserver_api.model.PinLikeDto
import jakarta.transaction.Transactional
import org.springframework.stereotype.Service
import java.util.*

@Service
class LikeServiceImpl(
    private val likeRepository: LikeRepository
): LikeService {
    override fun likeCountByPin(pinId: UUID, userId: UUID): PinLikeDto {
        val likeEntity = likeRepository.findLikeByUserIdAndPinId(userId, pinId)
        if (likeEntity.isEmpty) return PinLikeDto().apply {
            likeCount = 0
            likeArtCount = 0
            likePhotographyCount = 0
            likeArtCount = 0
            likedByUser = false
            likedPhotographyByUser = false
            likedArtByUser = false
            likedLocationByUser = false
        }
        val like = likeEntity.get()
        return PinLikeDto().apply {
            this.likeCount = likeRepository.countLikeByPinIdAndLikeIsTrue(pinId)
            this.likeArtCount = likeRepository.countLikeByPinIdAndLikeArtIsTrue(pinId)
            this.likePhotographyCount = likeRepository.countLikeByPinIdAndLikePhotographyIsTrue(pinId)
            this.likeLocationCount = likeRepository.countLikeByPinIdAndLikeLocationIsTrue(pinId)
            this.likedByUser = like.like
            this.likedPhotographyByUser = like.likePhotography
            this.likedArtByUser = like.likeArt
            this.likedLocationByUser = like.likeLocation
        }
    }

    @Transactional
    override fun createOrUpdateLike(createLikeDto: CreateLikeDto, pinId: UUID) {
        val likeOptional = likeRepository.findLikeByUserIdAndPinId(createLikeDto.userId, pinId)
        if (likeOptional.isEmpty) {
            val newLike = createLikeDto.toEntity(pinId)
            likeRepository.save(newLike)
        } else {
            val likeEntity = likeOptional.get()
            if (createLikeDto.like != null) likeEntity.like = createLikeDto.like
            if (createLikeDto.likeLocation != null) likeEntity.likeLocation = createLikeDto.likeLocation
            if (createLikeDto.likePhotography != null) likeEntity.likePhotography = createLikeDto.likePhotography
            if (createLikeDto.likeArt != null) likeEntity.likeArt = createLikeDto.likeArt
            likeRepository.save(likeEntity)
        }
    }


}