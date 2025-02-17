package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.entity.User

interface MessagingService {

    fun sendMessageToTopics(body: String, title: String, topic: String)

    fun sendMessageToUser(body: String, title: String, user: User)

}
