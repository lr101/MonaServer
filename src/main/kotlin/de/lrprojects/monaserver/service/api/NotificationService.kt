package de.lrprojects.monaserver.service.api

import com.google.firebase.messaging.FirebaseMessagingException
import java.util.*

interface NotificationService {

    @Throws(FirebaseMessagingException::class)
    fun sendNotificationToTopics(body: String, title: String, topic: String)

    fun sendNotificationToUser(body: String, title: String, userId: UUID, firebaseToken: String?)

}
