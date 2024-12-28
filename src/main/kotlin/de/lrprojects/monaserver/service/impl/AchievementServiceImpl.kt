package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.entity.UserAchievement
import de.lrprojects.monaserver.excepetion.AlreadyExistException
import de.lrprojects.monaserver.excepetion.ComparisonException
import de.lrprojects.monaserver.properties.AchievementProperties
import de.lrprojects.monaserver.repository.AchievementRepository
import de.lrprojects.monaserver.service.api.AchievementService
import de.lrprojects.monaserver.service.api.UserService
import de.lrprojects.monaserver.types.AchievementType
import de.lrprojects.monaserver.types.XpType
import de.lrprojects.monaserver_api.model.UserAchievementsDtoInner
import jakarta.persistence.EntityManager
import jakarta.transaction.Transactional
import org.springframework.stereotype.Service
import java.util.*

@Service
class AchievementServiceImpl(
    private val achievementRepository: AchievementRepository,
    private val achievementProperties: AchievementProperties,
    private val entityManager: EntityManager,
    private val userService: UserService
): AchievementService {

    @Transactional
    @Throws(AlreadyExistException::class, ComparisonException::class)
    override fun claimAchievement(userId: UUID, achievementId: Int) {
        val achievement = achievementRepository.findByUser_IdAndAchievementId(userId, achievementId)
        if (achievement.isPresent && achievement.get().claimed) {
            throw AlreadyExistException("Achievement is already claimed")
        } else {
            val claim = AchievementType.getById(achievementId).checkClaim(
                entityManager,
                getSqlParamMap(AchievementType.getById(achievementId).parameters, userId))
            if (claim) {
                val userAchievement: UserAchievement = if (achievement.isEmpty) {
                    UserAchievement(user = userService.getUser(userId), achievementId = achievementId, claimed = true)
                } else {
                    achievement.get().also { it.claimed = true }
                }
                achievementRepository.save(userAchievement)
                userService.addXp(userId, XpType.ACHIEVEMENT_XP)

            } else {
                throw ComparisonException("Achievement requirements not fulfilled")
            }
        }
    }

    @Transactional
    override fun getAchievement(userId: UUID): MutableList<UserAchievementsDtoInner> {
        val claimedAchievements = achievementRepository.findByUser_IdAndClaimedIsTrue(userId)
        val achievementResultList = mutableListOf<UserAchievementsDtoInner>()
        for (achievement in AchievementType.entries) {
            val value = achievement.runQuery(entityManager, getSqlParamMap(achievement.parameters, userId))
            achievementResultList.add(getAchievementDto(
                achievement,
                value,
                claimedAchievements
            ))
        }
        return  achievementResultList
    }

    private fun getAchievementDto(
        achievementType: AchievementType,
        currentValue: Int,
        claimed: List<UserAchievement>
    ) = UserAchievementsDtoInner().also {
        it.achievementId = achievementType.id
        it.claimed = claimed.any { ach -> ach.achievementId == achievementType.id }
        it.currentValue = currentValue
        it.thresholdValue = achievementType.threshold
        it.thresholdUp = achievementType.thresholdUp
    }

    private fun getSqlParamMap(params: List<String>, userId: UUID): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        for (param in params) {
            map[param] = when (param) {
                "userId" ->  userId
                "groupId" -> achievementProperties.monaGroupId
                "date" -> achievementProperties.createdBefore
                else -> {}
            }
        }
        return map
    }
}