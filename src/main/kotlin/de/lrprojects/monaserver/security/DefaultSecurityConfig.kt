package de.lrprojects.monaserver.security

import de.lrprojects.monaserver.config.RoleConstants.ADMIN_ROLE
import de.lrprojects.monaserver.config.RoleConstants.USER_ROLE
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
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
    private val userDetailsService: MyUserDetailsService,
) {

    @Bean
    fun securityFilterChain(http: HttpSecurity, jwtFilter: JWTFilter): SecurityFilterChain {
        http
            .csrf { it.disable() }
            .cors{ it.configurationSource(corsConfigurationSource())}
            .authorizeHttpRequests {
                it
                    .requestMatchers(PUBLIC_API_PATH, STATIC_PATH, PUBLIC_PATH, ERROR_PATH).permitAll()
                    .requestMatchers(API_PATH).hasAuthority(USER_ROLE)
                    .requestMatchers(ADMIN_PATH).hasAuthority(ADMIN_ROLE)
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
        return userDetailsService
    }

    @Bean
    fun passwordEncoder(): PasswordEncoder {
        return BCryptPasswordEncoder()
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
        const val API_PATH = "/api/v2/**"
        const val ADMIN_PATH = "/api/v2/admin/**"
    }

}