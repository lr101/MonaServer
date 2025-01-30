package de.lrprojects.monaserver

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication
import org.springframework.cache.annotation.EnableCaching
import org.springframework.scheduling.annotation.EnableScheduling


@SpringBootApplication(scanBasePackages = ["de.lrprojects"])
@ConfigurationPropertiesScan
@EnableCaching
@EnableScheduling
class MonaserverApplication
fun main(args: Array<String>) {
    runApplication<MonaserverApplication>(args = args)
}




