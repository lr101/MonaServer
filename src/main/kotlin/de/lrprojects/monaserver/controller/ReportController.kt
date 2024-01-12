package de.lrprojects.monaserver.controller

import org.openapitools.api.ReportApi

import org.openapitools.model.Report
import org.springframework.http.ResponseEntity

class ReportController : ReportApi {
    override fun createReport(report: Report?): ResponseEntity<Void> {
        return super.createReport(report)
    }

}