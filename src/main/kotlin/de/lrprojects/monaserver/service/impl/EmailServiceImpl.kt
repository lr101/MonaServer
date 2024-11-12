package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.properties.AppProperties
import de.lrprojects.monaserver.properties.MailProperties
import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver_api.model.ReportDto
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.EmailService
import jakarta.mail.MessagingException
import org.slf4j.LoggerFactory
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.mail.javamail.MimeMessageHelper
import org.springframework.stereotype.Service
import org.thymeleaf.context.Context
import org.thymeleaf.spring6.SpringTemplateEngine


@Service

class EmailServiceImpl(
    private val mailProperties: MailProperties,
    private val userRepository: UserRepository,
    private val mailSender: JavaMailSender,
    private val appProperties: AppProperties,
    private val templateEngine: SpringTemplateEngine
) : EmailService {



    @Throws(MailException::class)
    override fun sendMail(text: String, to: String, subject: String, html: Boolean) {
        try {
            if (logger.isInfoEnabled) logger.info("Trying to send mail to: $to")
            val message = mailSender.createMimeMessage()
            val helper = MimeMessageHelper(message, true);
            helper.setText(text, html)
            helper.setTo(to)
            helper.setFrom(mailProperties.from)
            helper.setSubject(subject)
            mailSender.send(message)
            if (logger.isInfoEnabled) logger.info("Send mail successfully to: $to")
        } catch (mex: MessagingException) {
            throw MailException(mex.message)
        }

    }

    @Throws(MailException::class, UserNotFoundException::class)
    override fun sendReportEmail(report: ReportDto) {
        val to: String
        try {
            to = userRepository.findById(report.userId).get().email!!
        } catch (_: Error) {
            throw UserNotFoundException("User with userId " + report.userId + " could not be found")
        }
        sendMail(report.message, to, report.report, false)
    }

    override fun sendDeleteCodeMail(username: String, code: String, to: String, urlPart: String) {
        val url = appProperties.url + DELETE_ACCOUNT_PATH + urlPart
        val ctx = Context()
        ctx.setVariable(USERNAME_VARIABLE_NAME, username)
        ctx.setVariable(CODE_VARIABLE_NAME, code)
        ctx.setVariable(LINK_VARIABLE_NAME, url)
        val content = templateEngine.process(DELETE_MAIL_TEMPLATE, ctx)
        sendMail(content, to, DELETE_CODE_SUBJECT, true)
    }

    override fun sendRecoveryMail(urlPart: String, to: String) {
        val url = appProperties.url + RECOVER_PATH + urlPart
        val ctx = Context()
        ctx.setVariable(LINK_VARIABLE_NAME, url);
        val content = templateEngine.process(RECOVER_MAIL_TEMPLATE,ctx)
        sendMail(content, to, RECOVER_SUBJECT, true)
    }

    companion object {
        private val logger = LoggerFactory.getLogger(this::class.java)
        private const val RECOVER_PATH = "/public/recover/"
        private const val DELETE_ACCOUNT_PATH = "/public/delete-account/"
        private const val RECOVER_SUBJECT = "Password Recovery"
        private const val DELETE_CODE_SUBJECT = "[Stick-It] Sad to see you go"
        private const val RECOVER_MAIL_TEMPLATE = "recover.html"
        private const val DELETE_MAIL_TEMPLATE = "delete.html"
        private const val LINK_VARIABLE_NAME = "link"
        private const val USERNAME_VARIABLE_NAME = "username"
        private const val CODE_VARIABLE_NAME = "code"

    }


}