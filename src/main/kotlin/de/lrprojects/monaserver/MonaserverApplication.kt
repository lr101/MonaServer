package de.lrprojects.monaserver

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.web.servlet.config.annotation.CorsRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer


@SpringBootApplication
class MonaserverApplication
fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(args = args)
}




