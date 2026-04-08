package de.lrprojects.monaserver.controller

import de.lrprojects.monaserverapi.api.ReportApiDelegate
import de.lrprojects.monaserverapi.model.ReportDto
import de.lrprojects.monaserver.service.api.EmailService
import org.slf4j.LoggerFactory
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class ReportController (private val emailService: EmailService) : ReportApiDelegate {

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

    override fun createReport(reportDto: ReportDto): ResponseEntity<Unit> {
        log.info("Attempting send report from user with id: ${reportDto.userId}")
        emailService.sendReportEmail(reportDto)
        return ResponseEntity.ok().build()
    }

}