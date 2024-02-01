package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.api.ReportApi
import de.lrprojects.monaserver.api.ReportApiDelegate

import de.lrprojects.monaserver.model.Report
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Component


@Component
class ReportController : ReportApiDelegate {
    override fun createReport(report: Report?): ResponseEntity<Void> {
        return super.createReport(report)
    }

}