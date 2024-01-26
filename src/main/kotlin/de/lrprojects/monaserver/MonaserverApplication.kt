package de.lrprojects.monaserver

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.ComponentScan
import org.springframework.data.jpa.repository.config.EnableJpaRepositories

@SpringBootApplication
@EnableJpaRepositories("de.lrprojects.monaserver.repository")
class MonaserverApplication

fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(*args)
}
