package de.lrprojects.monaserver.config

import com.google.auth.oauth2.AccessToken
import com.google.auth.oauth2.GoogleCredentials
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import de.lrprojects.monaserver.properties.AppProperties
import org.slf4j.LoggerFactory
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.context.annotation.Lazy
import java.io.FileInputStream
import java.time.Instant
import java.util.Date

@Configuration
class FirebaseConfig(
    private val appProperties: AppProperties
) {

    @Bean
    @Lazy
    fun firebaseMessaging(firebaseApp: FirebaseApp): FirebaseMessaging {
        return FirebaseMessaging.getInstance(firebaseApp)
    }

    @Bean
    @Lazy
    fun firebaseApp(credentials: GoogleCredentials): FirebaseApp {
        val options: FirebaseOptions = FirebaseOptions.builder()
            .setCredentials(credentials)
            .build()

        return FirebaseApp.initializeApp(options)
    }

    @Bean
    @Lazy
    fun googleCredentials(): GoogleCredentials {
        return try {
            if (appProperties.firebaseConfigPath == null) throw NullPointerException("The config file path is required")
            val fileStream = FileInputStream(appProperties.firebaseConfigPath)
            GoogleCredentials.fromStream(fileStream)
        } catch (e: Exception) {
            log.error("Could not load config file from the firebase: {}", e.message)
            GoogleCredentials.create(
                AccessToken("fake-token-placeholder", Date.from(Instant.now().plusSeconds(3600)))
            )
        }
    }

    companion object {
        private val log = LoggerFactory.getLogger(this::class.java)
    }

}