package de.lrprojects.monaserver.config

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties(prefix = "minio")
class MinioProperties {

    lateinit var endpoint: String
    lateinit var accessKey: String
    lateinit var secretKey: String
    lateinit var bucketName: String
}