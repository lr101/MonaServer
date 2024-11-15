package de.lrprojects.monaserver

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication
import org.springframework.cache.annotation.EnableCaching


@SpringBootApplication(scanBasePackages = ["de.lrprojects"])
@ConfigurationPropertiesScan
@EnableCaching
class MonaserverApplication
fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(args = args)
}




