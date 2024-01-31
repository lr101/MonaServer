package de.lrprojects.monaserver

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.autoconfigure.security.servlet.SecurityAutoConfiguration
import org.springframework.boot.runApplication


@SpringBootApplication(exclude = [SecurityAutoConfiguration::class])
class MonaserverApplication

fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(args = args)
}
