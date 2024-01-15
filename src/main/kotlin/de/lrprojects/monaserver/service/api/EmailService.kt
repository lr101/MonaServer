package de.lrprojects.monaserver.service.api

import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import org.openapitools.model.Report

interface EmailService {


    @Throws(MailException::class)
    fun sendMail(text: String, to: String, subject: String)

    @Throws(MailException::class, UserNotFoundException::class)
    fun sendReportEmail(report: Report)

}