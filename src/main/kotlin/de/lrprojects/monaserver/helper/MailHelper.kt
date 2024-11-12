package de.lrprojects.monaserver.helper

import de.lrprojects.monaserver.properties.MailProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.mail.javamail.JavaMailSenderImpl

@Configuration
class MailHelper(
    private val mailProperties: MailProperties
) {

    @Bean
    fun getMailSender(): JavaMailSender {
        val mailSender = JavaMailSenderImpl()
        mailSender.host = mailProperties.host
        mailSender.port = mailProperties.port
        mailSender.username = mailProperties.from
        mailSender.password = mailProperties.password
        val properties = mailSender.javaMailProperties
        properties["mail.transport.protocol"] = mailProperties.protocol
        properties["mail.smtp.ssl.enable"] = "true"
        properties["mail.smtp.auth"] = "true"
        return mailSender
    }

}