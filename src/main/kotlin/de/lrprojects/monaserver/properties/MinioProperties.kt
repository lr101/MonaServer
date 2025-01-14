package de.lrprojects.monaserver.properties

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "app.minio")
class MinioProperties {

    lateinit var endpoint: String
    lateinit var accessKey: String
    lateinit var secretKey: String
    lateinit var bucketName: String
    val urlExpiry: Int = 60
}