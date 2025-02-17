package de.lrprojects.monaserver.service.impl

import com.google.firebase.messaging.FirebaseMessaging
import com.google.firebase.messaging.FirebaseMessagingException
import com.google.firebase.messaging.Message
import com.google.firebase.messaging.Notification
import de.lrprojects.monaserver.entity.User
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.MessagingService
import org.springframework.stereotype.Service

@Service
class MessagingServiceImpl(
    private val fcm: FirebaseMessaging,
    private val userRepository: UserRepository
): MessagingService {

    override fun sendMessageToTopics(body: String, title: String, topic: String) {
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

    override fun sendMessageToUser(body: String, title: String, user: User) {
        log.info("Attempting to send message $title to user: ${user.username}")
        if (user.firebaseToken.isNullOrEmpty()) {
            log.info("User ${user.username} does not have a firebase token")
        } else {
            try {
                val msg = Message.builder()
                    .setToken(user.firebaseToken)
                    .setNotification(getNotification(title, body))
                    .build()

                fcm.send(msg)
            } catch (e: FirebaseMessagingException) {
                log.warn("Failed to send message to user ${user.username}: ${e.message}. Resetting token.")
                user.firebaseToken = null
                userRepository.save(user)
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