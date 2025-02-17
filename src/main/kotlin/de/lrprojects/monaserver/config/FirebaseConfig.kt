package de.lrprojects.monaserver.config

import com.google.auth.oauth2.GoogleCredentials
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.messaging.FirebaseMessaging
import de.lrprojects.monaserver.properties.AppProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import java.io.File


@Configuration
class FirebaseConfig(
    private val appProperties: AppProperties
) {

    @Bean
    fun firebaseMessaging(firebaseApp: FirebaseApp): FirebaseMessaging {
        return FirebaseMessaging.getInstance(firebaseApp)
    }

    @Bean
    fun firebaseApp(credentials: GoogleCredentials): FirebaseApp {
        val options: FirebaseOptions = FirebaseOptions.builder()
            .setCredentials(credentials)
            .build()

        return FirebaseApp.initializeApp(options)
    }

    @Bean
    fun googleCredentials(): GoogleCredentials {
        return if (appProperties.firebaseConfigPath != null) {
            GoogleCredentials.fromStream(File(appProperties.firebaseConfigPath).inputStream())
        } else {
            GoogleCredentials.getApplicationDefault()
        }
    }

}