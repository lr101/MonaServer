package de.lrprojects.monaserver.schedular

import de.lrprojects.monaserver.repository.PinRepository
import de.lrprojects.monaserver.service.impl.NotificationServiceImpl
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import java.util.*

@Service
class NotificationSchedular(
    private val notificationServiceImpl: NotificationServiceImpl,
    private val pinRepository: PinRepository,
) {


    //@Scheduled(cron = "0 0 14 * * SUN")

    @Scheduled(fixedDelay = 60000)
    fun scheduleNotification() {
        log.info("Scheduling notification for new pins")
        val result = pinRepository.findAllByCreationDateAfterRefreshToken()
        for (user in result) {
            val userId = user[0] as UUID
            val firebaseToken = user[1] as String?
            if (firebaseToken != null) {
                notificationServiceImpl.sendNotificationToUser(newPinsBody(user[2] as Int), NEW_PINS_TITLE, userId, firebaseToken)
            }
        }
    }

    companion object {
        private val log = org.slf4j.LoggerFactory.getLogger(this::class.java)
        private fun newPinsBody(pinsCount: Int) = "You are missing out on $pinsCount new sticks since you last visited!"
        const val NEW_PINS_TITLE = "You have new stickers in your feed."

    }

}