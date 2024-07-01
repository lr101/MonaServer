package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.ReportDto

interface EmailService {


    @Throws(MailException::class)
    fun sendMail(text: String, to: String, subject: String, html: Boolean)

    @Throws(MailException::class, UserNotFoundException::class)
    fun sendReportEmail(report: ReportDto)

    fun sendRecoveryMail(urlPart: String, to: String, )

    fun sendDeleteCodeMail(username: String, code: String, to: String, urlPart: String)

}