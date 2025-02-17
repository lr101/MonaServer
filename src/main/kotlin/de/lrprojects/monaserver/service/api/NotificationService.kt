package de.lrprojects.monaserver.service.api

import java.util.*

interface NotificationService {

    fun sendNotificationToTopics(body: String, title: String, topic: String)

    fun sendNotificationToUser(body: String, title: String, userId: UUID, firebaseToken: String?)

}
