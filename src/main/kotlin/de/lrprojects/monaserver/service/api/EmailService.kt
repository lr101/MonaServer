package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver_api.model.ReportDto

interface EmailService {

    @Throws(MailException::class, UserNotFoundException::class)
    fun sendReportEmail(report: ReportDto)

    fun sendEmailConfirmation(username: String, to: String, urlPart: String)

    fun sendRecoveryMail(urlPart: String, to: String, )

    fun sendDeleteCodeMail(username: String, code: String, to: String, urlPart: String)

    fun sendRoundMail(emails: List<String>?, subject: String, text: String, html: String?)

}