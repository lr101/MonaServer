package de.lrprojects.monaserver

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication


@SpringBootApplication(scanBasePackages = ["de.lrprojects"])
@ConfigurationPropertiesScan
class MonaserverApplication
fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(args = args)
}




