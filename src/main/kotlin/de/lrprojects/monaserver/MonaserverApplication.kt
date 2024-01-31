package de.lrprojects.monaserver

import io.swagger.v3.oas.annotations.OpenAPIDefinition
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication

@SpringBootApplication
@OpenAPIDefinition
class MonaserverApplication

fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(args = args)
}
