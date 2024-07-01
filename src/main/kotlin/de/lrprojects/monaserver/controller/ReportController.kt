package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.ReportApiDelegate
import de.lrprojects.monaserver.excepetion.MailException
import de.lrprojects.monaserver.excepetion.UserNotFoundException
import de.lrprojects.monaserver.model.ReportDto
import de.lrprojects.monaserver.service.api.EmailService
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class ReportController (private val emailService: EmailService) : ReportApiDelegate {
    override fun createReport(report: ReportDto): ResponseEntity<Void> {
        return try {
            emailService.sendReportEmail(report)
            ResponseEntity.ok().build()
        } catch (e: MailException) {
            ResponseEntity(HttpStatus.SERVICE_UNAVAILABLE)
        } catch (e: UserNotFoundException) {
            ResponseEntity.badRequest().build()
        } catch (e: Exception) {
            ResponseEntity.internalServerError().build()
        }
    }

}