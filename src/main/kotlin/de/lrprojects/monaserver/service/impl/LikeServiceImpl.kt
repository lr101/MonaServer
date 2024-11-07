package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toEntity
import de.lrprojects.monaserver.model.CreateLikeDto
import de.lrprojects.monaserver.model.PinLikeDto
import de.lrprojects.monaserver.repository.LikeRepository
import de.lrprojects.monaserver.service.api.LikeService
import jakarta.persistence.EntityNotFoundException
import org.springframework.stereotype.Service
import java.util.*

@Service
class LikeServiceImpl(
    private val likeRepository: LikeRepository
): LikeService {
    override fun likeCountByPin(pinId: UUID, userId: UUID): PinLikeDto {
        val likeEntity = likeRepository.findLikeByUserIdAndPinId(pinId, userId).orElseThrow { EntityNotFoundException("Like not found") }
        return PinLikeDto().apply {
            this.likeCount = likeRepository.countLikeByPinIdAndLikeIsTrue(pinId)
            this.likeArtCount = likeRepository.countLikeByPinIdAndLikeArtIsTrue(pinId)
            this.likePhotographyCount = likeRepository.countLikeByPinIdAndLikePhotographyIsTrue(pinId)
            this.likeArtCount = likeRepository.countLikeByPinIdAndLikeLocationIsTrue(pinId)
            this.likedByUser = likeEntity.like
            this.likedPhotographyByUser = likeEntity.likePhotography
            this.likedArtByUser = likeEntity.likeArt
            this.likedLocationByUser = likeEntity.likeLocation
        }
    }
    override fun createOrUpdateLike(createLikeDto: CreateLikeDto, pinId: UUID) {
        val newLike = createLikeDto.toEntity(pinId)
        likeRepository.save(newLike)
    }


}