package de.lrprojects.monaserver.controller

import de.lrprojects.monaserver.helper.ImageMigrationService
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.GetMapping

@Controller
class AdminController(
    private val imageMigrationService: ImageMigrationService
) {

    @GetMapping("/public/migration/1")
    fun runImageMigration(): ResponseEntity<Void> {
        imageMigrationService.migratePinImagesToMinio(100)
        imageMigrationService.migrateGroupImagesToMinio()
        imageMigrationService.migrateUserProfileToMinio(100)
        return ResponseEntity.ok().build()
    }

    @GetMapping("/public/migration/2")
    fun runGroupImageSmallMigration(): ResponseEntity<Void> {
        imageMigrationService.createSmallGroupImages()
        return ResponseEntity.ok().build()
    }

}