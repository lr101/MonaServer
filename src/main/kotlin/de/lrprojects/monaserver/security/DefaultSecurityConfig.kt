package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.properties.RoleConstants.ADMIN_ROLE
import de.lrprojects.monaserver.properties.RoleConstants.USER_ROLE
import de.lrprojects.monaserver.properties.TokenProperties
import de.lrprojects.monaserver.repository.UserRepository
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.DelegatingPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.CorsConfigurationSource
import org.springframework.web.cors.UrlBasedCorsConfigurationSource


@EnableWebSecurity
@Configuration
@EnableMethodSecurity(
    prePostEnabled = true,
    securedEnabled = true,
    jsr250Enabled = true)
class DefaultSecurityConfig (
    private val userRepository: UserRepository,
    private val tokenProperties: TokenProperties
) {

    @Bean
    fun securityFilterChain(http: HttpSecurity, jwtFilter: JWTFilter): SecurityFilterChain {
        http
            .csrf { it.disable() }
            .cors{ it.configurationSource(corsConfigurationSource())}
            .httpBasic { it.disable() }
            .formLogin { it.disable() }
            .authorizeHttpRequests {
                it
                    .requestMatchers(ADMIN_PATH, ACTUATOR_PATH).hasAuthority(ADMIN_ROLE)
                    .requestMatchers(PUBLIC_API_PATH, STATIC_PATH, PUBLIC_PATH, ERROR_PATH, FAVICON_PATH).permitAll()
                    .requestMatchers(API_PATH).hasAuthority(USER_ROLE)
                    .anyRequest().authenticated()
            }
            .sessionManagement {
                it.sessionCreationPolicy(SessionCreationPolicy.STATELESS)
            }
            .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter::class.java)
        return http.build()
    }

    @Bean
    fun userDetailsService(): UserDetailsService {
        return MyUserDetailsService(userRepository, tokenProperties)
    }

    @Bean
    fun delegatingPasswordEncoder(): PasswordEncoder {
        val defaultEncoder: PasswordEncoder = NoSaltPasswordEncoder()
        val encoders: MutableMap<String, PasswordEncoder> = HashMap()
        encoders["bcrypt"] = BCryptPasswordEncoder()
        val passwordEncoder = DelegatingPasswordEncoder("bcrypt", encoders)
        passwordEncoder.setDefaultPasswordEncoderForMatches(defaultEncoder)
        return passwordEncoder
    }


    @Bean
    fun corsConfigurationSource(): CorsConfigurationSource? {
        val configuration = CorsConfiguration()
        configuration.allowedOrigins = listOf("*")
        configuration.allowedMethods = listOf("*")
        configuration.allowedHeaders = listOf("*")
        val source = UrlBasedCorsConfigurationSource()
        source.registerCorsConfiguration("/**", configuration)
        return source
    }

    companion object {
        const val PUBLIC_API_PATH = "/api/v2/public/**"
        const val PUBLIC_PATH = "/public/**"
        const val STATIC_PATH = "/static/**"
        const val ERROR_PATH = "/error"
        const val FAVICON_PATH = "/favicon.ico"
        const val API_PATH = "/api/v2/**"
        const val ADMIN_PATH = "/api/v2/admin/**"
        const val ACTUATOR_PATH = "/actuator/**"
    }

}