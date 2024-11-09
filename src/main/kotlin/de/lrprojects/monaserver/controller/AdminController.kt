package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.service.ImageMigrationService
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.GetMapping

@Controller
class AdminController(
    private val imageMigrationService: ImageMigrationService
) {

    @GetMapping("/api/v2/admin/image-migration")
    fun runImageMigration(): ResponseEntity<Void> {
        imageMigrationService.migratePinImagesToMinio(100)
        imageMigrationService.migrateGroupImagesToMinio()
        imageMigrationService.migrateUserProfileToMinio(100)
        return ResponseEntity.ok().build()
    }

}