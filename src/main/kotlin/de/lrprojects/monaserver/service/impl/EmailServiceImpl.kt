package de.lrprojects.monaserver.service.impl

import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.repository.UserRepository
import de.lrprojects.monaserver.service.api.EmailService
import org.openapitools.model.Report
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.util.*
import javax.mail.*

import javax.mail.internet.InternetAddress

import javax.mail.internet.MimeMessage


@Service

class EmailServiceImpl constructor(
    @Value("email.from") var from: String,
    @Value("email.psw") var password: String,
    @Autowired var userRepository: UserRepository
    ) : EmailService {

    @Throws(MailException::class)
    override fun sendMail(text: String, to: String, subject: String) {

        // Assuming you are sending email from through gmails smtp
        val host = "smtp.gmail.com"

        // Get system properties
        val properties: Properties = System.getProperties()

        // Setup mail server
        properties["mail.smtp.host"] = host
        properties["mail.smtp.port"] = "465"
        properties["mail.smtp.ssl.enable"] = "true"
        properties["mail.smtp.auth"] = "true"

        // Get the Session object.// and pass username and password
        val session: Session = Session.getInstance(properties, object : Authenticator() {
            override fun getPasswordAuthentication(): PasswordAuthentication {
                return PasswordAuthentication(from, password)
            }
        })
        try {
            // Create a default MimeMessage object.
            val message = MimeMessage(session)

            // Set From: header field of the header.
            message.setFrom(InternetAddress(from))

            // Set To: header field of the header.
            message.addRecipient(Message.RecipientType.TO, InternetAddress(to))

            // Set Subject: header field
            message.subject = subject

            // Now set the actual message
            message.setText(text)
            println("sending...")
            // Send message
            Transport.send(message)
            println("Sent message successfully....")
        } catch (mex: MessagingException) {
            throw MailException(mex.message)
        }

    }

    @Throws(MailException::class, UserNotFoundException::class)
    override fun sendReportEmail(report: Report) {
        val to: String
        try {
            to = userRepository.findById(report.username).get().email!!
        } catch (_: Error) {
            throw UserNotFoundException("User with username" + report.username + " could not be found")
        }
        sendMail(report.message, to, report.report)
    }


}