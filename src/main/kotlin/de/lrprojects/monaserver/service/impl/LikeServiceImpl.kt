package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.converter.toEntity
import de.lrprojects.monaserver.repository.LikeRepository
import de.lrprojects.monaserver.service.api.LikeService
import de.lrprojects.monaserver.service.api.PinService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserverapi.model.CreateLikeDto
import de.lrprojects.monaserverapi.model.PinLikeDto
import de.lrprojects.monaserverapi.model.UserLikesDto
import jakarta.transaction.Transactional
import org.springframework.stereotype.Service
import java.util.*

@Service
class LikeServiceImpl(
    private val likeRepository: LikeRepository,
    private val userService: UserService,
    private val pinService: PinService,
): LikeService {

    override fun likeCountByPin(pinId: UUID, userId: UUID): PinLikeDto {
        val likeEntity = likeRepository.findLikeByUserIdAndPinId(userId, pinId)
        if (likeEntity.isEmpty) return PinLikeDto(
            likeCount = 0,
            likeArtCount = 0,
            likePhotographyCount = 0,
            likeLocationCount = 0,
            likedByUser = false,
            likedPhotographyByUser = false,
            likedArtByUser = false,
            likedLocationByUser = false
        )
        val like = likeEntity.get()
        return PinLikeDto(
            likeCount = likeRepository.countLikeByPinIdAndLikeAllIsTrue(pinId),
            likeArtCount = likeRepository.countLikeByPinIdAndLikeArtIsTrue(pinId),
            likePhotographyCount = likeRepository.countLikeByPinIdAndLikePhotographyIsTrue(pinId),
            likeLocationCount = likeRepository.countLikeByPinIdAndLikeLocationIsTrue(pinId),
            likedByUser = like.likeAll,
            likedPhotographyByUser = like.likePhotography,
            likedArtByUser = like.likeArt,
            likedLocationByUser = like.likeLocation,
        )
    }

    @Transactional
    override fun createOrUpdateLike(createLikeDto: CreateLikeDto, pinId: UUID) {
        val likeOptional = likeRepository.findLikeByUserIdAndPinId(createLikeDto.userId, pinId)
        val pin = pinService.getPin(pinId)
        if (likeOptional.isEmpty) {
            val user = userService.getUser(createLikeDto.userId)
            val newLike = createLikeDto.toEntity(pin, user)
            likeRepository.save(newLike)
        } else {
            val likeEntity = likeOptional.get()
            createLikeDto.like?.let {  likeEntity.likeAll = createLikeDto.like!! }
            createLikeDto.likeLocation?.let {  likeEntity.likeLocation = createLikeDto.likeLocation!! }
            createLikeDto.likePhotography?.let {  likeEntity.likePhotography = createLikeDto.likePhotography!! }
            createLikeDto.likeArt?.let {  likeEntity.likeArt = createLikeDto.likeArt!! }
            likeRepository.save(likeEntity)
        }
    }

    @Transactional
    override fun getUserLikes(userId: UUID): UserLikesDto {
        return UserLikesDto(
            likeCount = likeRepository.countLikeByPinCreator(userId),
            likeArtCount = likeRepository.countLikeArtByCreator(userId),
            likeLocationCount = likeRepository.countLikeLocationByCreator(userId),
            likePhotographyCount = likeRepository.countLikePhotographyByCreator(userId)
        )
    }


}