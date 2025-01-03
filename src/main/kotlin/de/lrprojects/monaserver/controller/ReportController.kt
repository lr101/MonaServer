package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver_api.api.ReportApiDelegate
import de.lrprojects.monaserver_api.model.ReportDto
import de.lrprojects.monaserver.service.api.EmailService
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class ReportController (private val emailService: EmailService) : ReportApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun createReport(report: ReportDto): ResponseEntity<Void>? {
        log.info("Attempting send report from user with id: ${report.userId}")
        emailService.sendReportEmail(report)
        return ResponseEntity.ok().build()
    }

}