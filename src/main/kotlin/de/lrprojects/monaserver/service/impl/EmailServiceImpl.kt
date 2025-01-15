package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.properties.AppProperties
import de.lrprojects.monaserver.properties.MailProperties
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.EmailService
import de.lrprojects.monaserver_api.model.ReportDto
import jakarta.mail.MessagingException
import org.slf4j.LoggerFactory
import org.springframework.mail.javamail.JavaMailSender
import org.springframework.mail.javamail.MimeMessageHelper
import org.springframework.scheduling.annotation.Async
import org.springframework.scheduling.annotation.EnableAsync
import org.springframework.stereotype.Service
import org.thymeleaf.context.Context
import org.thymeleaf.spring6.SpringTemplateEngine
import org.thymeleaf.templatemode.TemplateMode
import org.thymeleaf.templateresolver.StringTemplateResolver
import java.time.Duration
import java.util.*
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit


@Service
@EnableAsync
class EmailServiceImpl(
    private val mailProperties: MailProperties,
    private val userRepository: UserRepository,
    private val mailSender: JavaMailSender,
    private val appProperties: AppProperties,
    private val templateEngine: SpringTemplateEngine,
) : EmailService {



    @Throws(MailException::class)
    private fun sendMail(text: String, to: String, subject: String,  html: Boolean) {
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
        val user = userRepository.findById(report.userId).orElseThrow { UserNotFoundException("User not found") }
        val ctx = Context()
        ctx.setVariable(USERNAME_VARIABLE_NAME, user.username)
        ctx.setVariable(CONTENT_VARIABLE_NAME, report.report)
        ctx.setVariable(EMAIL_VARIABLE_NAME, user.email)
        ctx.setVariable(MESSAGE_VARIABLE_NAME, report.message)
        ctx.setVariable(APP_DOMAIN_VARIABLE_NAME, appProperties.url)
        ctx.setVariable(MAIL_VARIABLE, mailProperties.from)
        val content = templateEngine.process(REPORT_MAIL_TEMPLATE, ctx)
        sendMail(content, mailProperties.username, report.report, true)
    }

    override fun sendDeleteCodeMail(username: String, code: String, to: String, urlPart: String) {
        val url = appProperties.url + DELETE_ACCOUNT_PATH + urlPart
        val ctx = Context()
        ctx.setVariable(USERNAME_VARIABLE_NAME, username)
        ctx.setVariable(CODE_VARIABLE_NAME, code)
        ctx.setVariable(LINK_VARIABLE_NAME, url)
        ctx.setVariable(APP_DOMAIN_VARIABLE_NAME, appProperties.url)
        ctx.setVariable(MAIL_VARIABLE, mailProperties.from)
        val content = templateEngine.process(DELETE_MAIL_TEMPLATE, ctx)
        sendMail(content, to, DELETE_CODE_SUBJECT, true)
    }

    override fun sendRecoveryMail(urlPart: String, to: String) {
        val url = appProperties.url + RECOVER_PATH + urlPart
        val ctx = Context()
        ctx.setVariable(LINK_VARIABLE_NAME, url);
        ctx.setVariable(APP_DOMAIN_VARIABLE_NAME, appProperties.url)
        ctx.setVariable(MAIL_VARIABLE, mailProperties.from)
        val content = templateEngine.process(RECOVER_MAIL_TEMPLATE,ctx)
        sendMail(content, to, RECOVER_SUBJECT, true)
    }

    @Async
    override fun sendRoundMail(emails: List<String>?, subject: String, text: String, html: String?) {
        val mails: List<Array<String>> = if(!emails.isNullOrEmpty()) emails.map { e -> arrayOf(e, e) }.toList() else userRepository.findAllEmails()
        val scheduler = Executors.newScheduledThreadPool(1)
        val duration = Duration.ofMinutes(mailProperties.batchDuration / mailProperties.batchSize).toMillis()


        val stringTemplateResolver = StringTemplateResolver().apply {
            templateMode = TemplateMode.HTML
            checkExistence = false
        }

        val stringTemplateEngine = SpringTemplateEngine().apply {
            setTemplateResolver(stringTemplateResolver)
        }

        mails.forEachIndexed { index, mail ->
            var content: String = text
            if (html != null) {
                val ctx = Context()
                ctx.setVariable(USERNAME_VARIABLE_NAME, mail[1])
                ctx.setVariable(APP_DOMAIN_VARIABLE_NAME, appProperties.url)
                ctx.setVariable(MAIL_VARIABLE, mailProperties.from)
                content = stringTemplateEngine.process(html, ctx)
            }
            scheduler.schedule({ sendMail(content, mail[0], subject, html != null) },
                duration * index,
                TimeUnit.MILLISECONDS
            )
        }
        scheduler.shutdown()
    }

    companion object {
        private val logger = LoggerFactory.getLogger(this::class.java)
        private const val RECOVER_PATH = "/public/recover/"
        private const val DELETE_ACCOUNT_PATH = "/public/delete-account/"
        private const val RECOVER_SUBJECT = "Password Recovery"
        private const val DELETE_CODE_SUBJECT = "[Stick-It] Sad to see you go"
        private const val RECOVER_MAIL_TEMPLATE = "recover.html"
        private const val REPORT_MAIL_TEMPLATE = "report.html"
        private const val DELETE_MAIL_TEMPLATE = "delete.html"
        private const val LINK_VARIABLE_NAME = "link"
        private const val USERNAME_VARIABLE_NAME = "username"
        private const val EMAIL_VARIABLE_NAME = "email"
        private const val CONTENT_VARIABLE_NAME = "content"
        private const val MESSAGE_VARIABLE_NAME = "message"
        private const val MAIL_VARIABLE = "mail"
        private const val APP_DOMAIN_VARIABLE_NAME = "appdomain"
        private const val CODE_VARIABLE_NAME = "code"

    }


}