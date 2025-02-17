package de.lrprojects.monaserver.service.impl

import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingException
import com.google.firebase.messaging.Message
import com.google.firebase.messaging.Notification
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.NotificationService
import org.springframework.stereotype.Service
import java.util.*
import kotlin.jvm.optionals.getOrNull

@Service
class NotificationServiceImpl(
    private val fcm: FirebaseMessaging,
    private val userRepository: UserRepository
): NotificationService {

    override fun sendNotificationToTopics(body: String, title: String, topic: String) {
        log.info("Attempting to send message $title to topic: $topic")
        val msg = Message.builder()
            .setNotification(getNotification(title, body))
            .setTopic(topic)
            .build()
        try {
            fcm.send(msg)
        }  catch (e: FirebaseMessagingException) {
            log.error("Error creating notification for topic $topic: ${e.message}")
        }
    }

    override fun sendNotificationToUser(body: String, title: String, userId: UUID, firebaseToken: String?) {
        log.info("Attempting to send message $title to user: $userId")
        if (firebaseToken == null) {
            log.info("User $userId does not have a firebase token")
        } else {
            try {
                val msg = Message.builder()
                    .setToken(firebaseToken)
                    .setNotification(getNotification(title, body))
                    .build()

                fcm.send(msg)
            } catch (e: FirebaseMessagingException) {
                log.warn("Failed to send message to user $userId: ${e.message}. Resetting token.")
                userRepository.findById(userId).getOrNull()?.let {
                    it.firebaseToken = null
                    userRepository.save(it)
                }
            }
        }
    }

    private fun getNotification(title: String, body: String): Notification {
        return Notification.builder()
            .setTitle(title)
            .setBody(body)
            .build()
    }

    companion object {
        private val log = org.slf4j.LoggerFactory.getLogger(this::class.java)
    }

}